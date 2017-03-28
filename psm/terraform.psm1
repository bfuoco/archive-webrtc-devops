function Test-Terraform
{
    [CmdletBinding()]
    Param()
    $ErrorActionPreference = "Stop"

    $RequiredVersion = "0.7.0"

    Write-Host "`nChecking Terraform installation:"

    $TerraformLocation = Get-Command "terraform" -ErrorAction "SilentlyContinue"
    if (-Not ($TerraformLocation))
    {
        Write-Host ""
        throw "Terraform is not installed or is not in PATH."
    }
    
    Write-Host -ForegroundColor DarkGray "`tLocation : $($TerraformLocation.Source)"
    
    $CurrentVersionRaw = terraform -version
    $CurrentVersion = $CurrentVersionRaw.Split(" ")[1].TrimStart("v")
    
    Write-Host "`nChecking Terraform version:"
    Write-Host -ForegroundColor DarkGray "`tCurrent  : $CurrentVersion"
    Write-Host -ForegroundColor DarkGray "`tRequired : $RequiredVersion"
    
    if ([Version]$CurrentVersion -lt [Version]$RequiredVersion)
    {
        Write-Host ""
        throw "Terraform version is outdated. Update to version $RequiredVersion."
    }       
}

function Apply-Infrastructure
{
    [CmdletBinding()]
    Param([string]$AwsRegion, [string]$RoleGroup, [string]$Environment)
    $ErrorActionPreference = "Stop"

    $S3Bucket = "orbba-webrtc"
    
    try
    {
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
            Write-Host ""
            throw "Unknown role group."
        }

        $TimeStamp = [Math]::floor((Get-Date -UFormat %s))
        $LogPath = "$PWD\logs\apply-$TimeStamp.log"
        
        $Env:TF_LOG = "DEBUG"
        $Env:TF_LOG_PATH = $LogPath

        Write-Host "`nApplying infrastructure."
        Write-Host -ForegroundColor DarkGray "`tLocation : $PWD"
        Write-Host -ForegroundColor DarkGray "`tLog file : $LogPath"

        $StateExists = Test-Path ".terraform\terraform.tfstate"
        if ($StateExists)
        {
            $StateData = Get-Content -Raw -Path ".terraform\terraform.tfstate" | ConvertFrom-Json
            if ($StateData.Remote.Config.Bucket -ne $S3Bucket)
            {
                $OverrideConfigureState = $True
            }
        }
        
        if (-Not $StateExists -Or $OverrideConfigureState)
        {
            if ($OverrideConfigureState)
            {
                Write-Host "`nRemote state is will be reconfigured:"
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

            $TerraformCmd = "terraform remote config " + `
                "-backend=s3 " + `
                '-backend-config="bucket=$S3Bucket" ' + `
                '-backend-config="key=$S3Key" ' + `
                '-backend-config="region=$AwsRegion"'

            Write-Host "Using Terraform command: $TerraformCmd"
            Invoke-Expression $TerraformCmd
        }
        else
        {
            Write-Host "`nRemote state is configured."
            Write-Host -ForegroundColor DarkGray "`tBucket : $S3Bucket"
            Write-Host -ForegroundColor DarkGray "`tKey    : $S3Key"
            Write-Host -ForegroundColor DarkGray "`tRegion : $AwsRegion"
        }

        $TerraformCmd = "terraform get"

        Write-Host "`nUpdating terraform modules."
        Write-Host "Using Terraform command: $TerraformCmd"
        Invoke-Expression $TerraformCmd
        
        if ($LastExitCode -ne 0)
        {
            Write-Host ""
            throw "An error occurred in terraform."
        }

        $TerraformCmd = "terraform apply "

        Write-Host "`nApplying infrastructure changes."
        Write-Host "Using Terraform command: $TerraformCmd"
        Invoke-Expression $TerraformCmd
        
        if ($LastExitCode -ne 0)
        {
            Write-Host ""
            throw "An error occurred in terraform."
        }
    }
    catch
    {
        Write-Host -ForegroundColor Red $_.Exception.Message
    }
    finally
    {
        Pop-Location
        Pop-Location
        Pop-Location
        
        Remove-Item Env:TF_LOG
        Remove-Item Env:TF_LOG_PATH
        
        $LogLines = Get-Content $LogPath
        
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
}

function Destroy-Infrastructure
{
    [CmdletBinding()]
    Param([string]$RoleGroup, [string]$Environment)
    $ErrorActionPreference = "Stop"

    $S3Bucket = "orbba-webrtc"
    
    try
    {
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
            Write-Host ""
            throw "Unknown role group."
        }
        
        $TimeStamp = [Math]::floor((Get-Date -UFormat %s))
        $LogPath = "$PWD\logs\destroy-$TimeStamp.log"

        $Env:TF_LOG = "DEBUG"
        $Env:TF_LOG_PATH = $LogPath
        
        $TerraformCmd = "terraform destroy"

        Write-Host "`nDestroying all infrastructure."
        Write-Host "Using command : $TerraformCmd"
        Write-Host -ForegroundColor DarkGray "`tLocation : $PWD"
        Write-Host -ForegroundColor DarkGray "`tLog file : $LogPath"

        Write-Host "'"
        Invoke-Expression $TerraformCmd -ErrorAction SilentlyContinue
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
        
        $LogLines = Get-Content $LogPath
        
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
}

Export-ModuleMember -function Test-Terraform
Export-ModuleMember -function Apply-Infrastructure
Export-ModuleMember -function Destroy-Infrastructure
