<#
Test whether or not the user has the required Terraform version.
#>
function Test-Terraform
{
    $RequiredVersion = "0.7.2"

    Write-Host "`nChecking Terraform installation:"

    $TerraformLocation = Get-Command "terraform" -ErrorAction "SilentlyContinue"
    if (-Not ($TerraformLocation))
    {
        throw "Terraform is not installed or is not in PATH."
    }
    
    Write-Host -ForegroundColor DarkGray "`tLocation : $($TerraformLocation.Source)"
    
    $CurrentVersionRaw = terraform -version
    $CurrentVersion = $CurrentVersionRaw.Split(" ")[1].TrimStart("v")

    try
    {
        $Html = (Invoke-WebRequest "https://releases.hashicorp.com/terraform").ParsedHtml
        $LatestVersion = $Html.GetElementsByTagName("a")[1].InnerHtml
        $LatestVersion = $LatestVersion.Split("_")[1]
    }
    catch
    {
    }

    Write-Host "`nChecking Terraform version:"
    Write-Host -ForegroundColor DarkGray "`tCurrent  : $CurrentVersion"
    Write-Host -ForegroundColor DarkGray "`tRequired : $RequiredVersion"
    if ($LatestVersion -ne $Null)
    {
        Write-Host -ForegroundColor DarkGray "`tLatest   : $LatestVersion"
    }

    if ([Version]$CurrentVersion -lt [Version]$RequiredVersion)
    {
        throw "Terraform version is outdated. Update to version $RequiredVersion."
    }       
}

<#
Applys the infrastructure configuration to AWS.
#>
function Apply-Infrastructure
{
    Param([string]$AwsRegion, [string]$RoleGroup, [string]$Environment)
    
    $S3Bucket = "orbba-webrtc"
    
    try
    {
        $TimeStamp = [Math]::floor((Get-Date -UFormat %s))
    
        Push-Location "terraform"
        Push-Location $RoleGroup

        if ($RoleGroup -eq "core")
        {
            Push-Location "main-$Environment"
            $S3Key = "$RoleGroup/main-$Environment.tfstate"
        }
        elseif ($RoleGroup -eq "meta")
        {
            Push-Location "main"
            $S3Key = "$RoleGroup/main.tfstate"
        }
        else
        {
            throw "Unknown role group."
        }

        $LogPath = "logs\apply-$TimeStamp.log"
        $LogFile = "$PWD\$LogPath"
        $Env:TF_LOG = "DEBUG"
        $Env:TF_LOG_PATH = $LogFile

        Write-Host "`nApplying infrastructure."
        Write-Host -ForegroundColor DarkGray "`Role Group : $RoleGroup"
        Write-Host -ForegroundColor DarkGray "`tLog file  : $LogPath"

        $StateExists = Test-Path ".terraform\terraform.tfstate"
        if ($StateExists)
        {
            $StateData = Get-Content -Raw -Path ".terraform\terraform.tfstate" | ConvertFrom-Json
            if ($StateData.Remote.Config.Bucket -ne $S3Bucket)
            {
                $OverrideConfigureState = $True
            }
            elseif ($StateData.Remote.Config.Key -ne $S3Key) {
                $OverrideConfigureState = $True
            }
        }
        
        if (-Not $StateExists -Or $OverrideConfigureState)
        {
            if ($OverrideConfigureState)
            {
                Write-Host "`nRemote state will be reconfigured:"
                Write-Host -ForegroundColor DarkGray "`tOld Bucket : $($StateData.Remote.Config.Bucket)"
                Write-Host -ForegroundColor DarkGray "`tNew Bucket : $S3Bucket"
                Write-Host -ForegroundColor DarkGray "`tKey        : $S3Key"
                Write-Host -ForegroundColor DarkGray "`tRegion     : $AwsRegion"
            }
            else
            {
                Write-Host "`nRemote state will be configured:"
                Write-Host -ForegroundColor DarkGray "`tBucket : $S3Bucket"
                Write-Host -ForegroundColor DarkGray "`tKey    : $S3Key"
                Write-Host -ForegroundColor DarkGray "`tRegion : $AwsRegion"
            }

            $TerraformExpression = "terraform remote config " + `
                "-backend=s3 " + `
                '-backend-config="bucket=$S3Bucket" ' + `
                '-backend-config="key=$S3Key" ' + `
                '-backend-config="region=$AwsRegion"'

            Write-Host "Using Terraform command: $TerraformExpression"
            Invoke-Expression $TerraformExpression
        }
        else
        {
            Write-Host "`nRemote state is configured."
            Write-Host -ForegroundColor DarkGray "`tBucket : $S3Bucket"
            Write-Host -ForegroundColor DarkGray "`tKey    : $S3Key"
            Write-Host -ForegroundColor DarkGray "`tRegion : $AwsRegion"
        }

        $TerraformExpression = "terraform get"

        Write-Host "`nUpdating terraform modules."
        Write-Host "Using Terraform command: $TerraformExpression"
        Invoke-Expression $TerraformExpression
        
        if ($LastExitCode -ne 0)
        {
            throw "An error occurred in terraform."
        }

        $TerraformExpression = "terraform apply"

        Write-Host "`nApplying infrastructure changes."
        Write-Host "Using Terraform command: $TerraformExpression"
        Invoke-Expression $TerraformExpression
        
        if ($LastExitCode -ne 0)
        {
            throw "An error occurred in terraform."
        }
    }
    catch
    {
        Write-Host $_.Exception
        $Exception = $_.Exception
    }
    finally
    {
        Remove-Item Env:TF_LOG
        Remove-Item Env:TF_LOG_PATH
        Pop-Location
        Pop-Location
        Pop-Location
        
        $LogLines = Get-Content $LogFile
        
        for ($i = 0; $i -lt $LogLines.Length; $i++)
        {
            if ($LogLines[$i].Contains("HTTP/1.1 403 Forbidden"))
            {
                $Result = $LogLines[$i - 2] -Match "^.*Response (.*) Details.*$"
                if ($Result)
                {
                    Write-Host "IAM policy is missing required permission: $($Matches[1])"
                }
            }
        }
    }
    
    if ($Exception -ne $Null)
    {
        throw $Exception
    }    
}

<#
Destroys managed infrastructure.
#>
function Destroy-Infrastructure
{
    Param([string]$RoleGroup, [string]$Environment)

    $S3Bucket = "orbba-webrtc"
    
    try
    {
        $TimeStamp = [Math]::floor((Get-Date -UFormat %s))
        
        Push-Location "terraform"
        Push-Location $RoleGroup

        if ($RoleGroup -eq "core")
        {
            Push-Location "main-$Environment"
            $S3Key = "$RoleGroup/main-$Environment.tfstate"
        }
        elseif ($RoleGroup -eq "meta")
        {
            Push-Location "main"
            $S3Key = "$RoleGroup/main.tfstate"
        }
        else
        {
            throw "Unknown role group."
        }

        $LogPath = "logs\destroy-$TimeStamp.log"
        $LogFile = "$PWD\$LogPath"
        $Env:TF_LOG = "DEBUG"
        $Env:TF_LOG_PATH = $LogFile
        
        $TerraformExpression = "terraform destroy"

        Write-Host "`nDestroying all infrastructure."
        Write-Host "Using command : $TerraformExpression"
        Write-Host -ForegroundColor DarkGray "`tRole Group : $RoleGroup"
        Write-Host -ForegroundColor DarkGray "`tLog file   : $LogPath"
        Write-Host ""

        Invoke-Expression $TerraformExpression -ErrorAction SilentlyContinue
    }
    catch
    {
        Write-Host -ForegroundColor Red $_.Exception.Message
    }
    finally
    {
        Remove-Item Env:TF_LOG
        Remove-Item Env:TF_LOG_PATH
        Pop-Location
        Pop-Location
        Pop-Location
        
        $LogLines = Get-Content $LogFile
        
        for ($i = 0; $i -lt $LogLines.Length; $i++)
        {
            if ($LogLines[$i].Contains("HTTP/1.1 403 Forbidden"))
            {
                $Result = $LogLines[$i - 2] -Match "^.*Response (.*) Details.*$"
                if ($Result)
                {
                    Write-Host "IAM policy is missing required permission: $($Matches[1])"
                }
            }
        }        
    }
    
    if ($Exception -ne $Null)
    {
        throw $Exception
    }
}

Export-ModuleMember -function Test-Terraform
Export-ModuleMember -function Apply-Infrastructure
Export-ModuleMember -function Destroy-Infrastructure
