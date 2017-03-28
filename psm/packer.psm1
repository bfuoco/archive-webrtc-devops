<#
Tests whether or not the user has the required Packer version.
#>
function Test-Packer
{
    $RequiredVersion = "0.10.1"

    Write-Host "`nChecking Packer installation:"

    $PackerLocation = Get-Command "packer" -ErrorAction "SilentlyContinue"
    if (-Not ($PackerLocation))
    {
        throw "Packer is not installed or is not in PATH."
    }
    
    Write-Host -ForegroundColor DarkGray "`tLocation: $($PackerLocation.Source)"
    
    $CurrentVersion = packer -version

    try
    {
        $Html = (Invoke-WebRequest "https://releases.hashicorp.com/packer").ParsedHtml
        $LatestVersion = $Html.GetElementsByTagName("a")[1].InnerHtml
        $LatestVersion = $LatestVersion.Split("_")[1]
    }
    catch
    {
    }

    Write-Host "`nChecking Packer version:"
    Write-Host -ForegroundColor DarkGray "`tCurrent  : $CurrentVersion"
    Write-Host -ForegroundColor DarkGray "`tRequired : $RequiredVersion"
    if ($LatestVersion -ne $Null)
    {
        Write-Host -ForegroundColor DarkGray "`tLatest   : $LatestVersion"
    }

    if ([Version]$CurrentVersion -lt [Version]$RequiredVersion)
    {
        throw "Packer version is outdated. Update to version $RequiredVersion."
    }       
}

<#
Builds an EBS-backed AMI for the specified role.
#>
function Build-Ami
{
    Param([string]$RegionId, [string]$UbuntuAmiId, [string]$RoleGroup, [string]$Role, [string]$Environment)

    $Exception = $Null
    
    try
    {
        $TimeStamp = [Math]::floor((Get-Date -UFormat %s))
        
        Push-Location "packer"
        Push-Location $RoleGroup
        
        $InstanceType = "t2.micro"
        $LogFile = "logs\$Role-$TimeStamp"
        $LogPath = "$PWD\$LogFile"
        $Env:PACKER_LOG = 1
        $Env:PACKER_LOG_PATH = $LogPath
        
        $PackerExpression = "packer build " +
            "-var 'component=webrtc' " +
            "-var 'owner=test' " +
            "-var 'aws_region=$RegionId' " +
            "-var 'aws_source_ami=$UbuntuAmiId' " +
            "-var 'aws_instance_type=$InstanceType' "

        if ($RoleGroup -eq "core")
        {
            $PackerExpression = "$PackerExpression -var 'environment=$Environment'"
        }
        
        $PackerExpression = "$PackerExpression $Role.json"

        Write-Host "`nBuilding AMI for $($Role):"
        Write-Host "Using Packer command: $PackerExpression"
        Write-Host -ForegroundColor DarkGray "`tPacker file : $Role.json"
        Write-Host -ForegroundColor DarkGray "`tLog file    : $LogFile"
        Write-Host -ForegroundColor DarkGray "`tInstance    : $InstanceType"
        Write-Host ""

        Invoke-Expression $PackerExpression | Tee-Object -Variable PackerResult
        
        $PackerResult = (-Join $PackerResult)
        if ($PackerResult.Contains("didn't complete successfully"))
        {
            throw "Fatal error while executing Packer command."
        }
        elseif ($PackerResult.Contains("invalid 'tags'"))
        {
            throw "Fatal error while executing Packer command."
        }
        elseif ($PackerResult.Contains("error(s) occurred:"))
        {
            throw "Fatal error while executing Packer command."
        }
    }
    catch
    {
        Write-Host $_.Exception
        $Exception = $_.Exception
    }
    finally
    {
        Remove-Item Env:PACKER_LOG
        Remove-Item Env:PACKER_LOG_PATH
        Pop-Location
        Pop-Location
    }
    
    if ($Exception -ne $Null)
    {
        if ($PackerResult.Contains("Timeout waiting for ssh"))
        {
            Write-Host "`nSSH timeout. This is most likely a temporary network error. Trying again."
            Build-Ami $RegionId $UbuntuAmiId $RoleGroup $Role $Environment
        }
        else
        {
            throw $Exception
        }
    }
}

Export-ModuleMember -function Test-Packer
Export-ModuleMember -function Build-Ami
