function Test-Packer
{
    $ErrorActionPreference = "Stop"
    $RequiredVersion = "0.10.1"

    Write-Host "`nChecking Packer installation:"

    $PackerLocation = Get-Command "packer" -ErrorAction "SilentlyContinue"
    if (-Not ($PackerLocation))
    {
        Write-Host ""
        throw "Packer is not installed or is not in PATH."
    }
    
    Write-Host -ForegroundColor DarkGray "`tLocation: $($PackerLocation.Source)"
    
    $CurrentVersion = packer -version
    
    Write-Host "`nChecking Packer version:"
    Write-Host -ForegroundColor DarkGray "`tCurrent  : $CurrentVersion"
    Write-Host -ForegroundColor DarkGray "`tRequired : $RequiredVersion"
    
    if ([Version]$CurrentVersion -lt [Version]$RequiredVersion)
    {
        Write-Host ""
        throw "Packer version is outdated. Update to version $RequiredVersion."
    }       
}

function Build-Ami
{
    Param([string]$RegionId, [string]$UbuntuAmiId, [string]$RoleGroup, [string]$Role, [string]$Environment)
    $ErrorActionPreference = "Stop"

    $TimeStamp = [Math]::floor((Get-Date -UFormat %s))

    Push-Location "packer"
    Push-Location $RoleGroup
    
    try
    {
        $LogPath = "$PWD\logs\$Role-$TimeStamp"
        $InstanceType = "t2.micro"
        
        $Env:PACKER_LOG = 1
        $Env:PACKER_LOG_PATH = $LogPath
        
        $PackerCmd = "packer build " +
            "-var 'component=webrtc' " +
            "-var 'owner=fm' " +
            "-var 'aws_region=$RegionId' " +
            "-var 'aws_source_ami=$UbuntuAmiId' " +
            "-var 'aws_instance_type=$InstanceType' "

        if ($RoleGroup -eq "core")
        {
            $PackerCmd = "$PackerCmd -var 'environment=$Environment'"
        }
        
        $PackerCmd = "$PackerCmd $Role.json"

        Write-Host "`nBuilding AMI for $($Role):"
        Write-Host "Using Packer command: $PackerCmd"
        Write-Host -ForegroundColor DarkGray "`tLocation : $PWD"
        Write-Host -ForegroundColor DarkGray "`tLog file : $LogPath"
        Write-Host -ForegroundColor DarkGray "`tInstance : $InstanceType"
        Write-Host ""

        # Not strictly necessary but sometimes if you want to comment out the Invoke-Expression
        # statement, it will cause an error in the finally block otherwise.
        $LastExitCode = 0
        Invoke-Expression $PackerCmd

        echo $?
    }
    catch
    {
        $PackerErr = $_.Exception.Message
    }
    finally
    {
        Remove-Item Env:PACKER_LOG
        Remove-Item Env:PACKER_LOG_PATH
        Pop-Location
        Pop-Location

        if ($LastExitCode -gt 0)
        {
            Write-Host ""
            throw "Fatal error during packer run."
        }
        if ($PackerErr -ne $Null)
        {
            Write-Host ""
            throw $PackerErr
        }
    }
}

Export-ModuleMember -function Test-Packer
Export-ModuleMember -function Build-Ami
