<#
Deploys build artifacts.
#>
Param(
    [Parameter()]
    [string]
    $Environment,

    [Parameter()]
    [string[]]
    $Roles
)

$ErrorActionPreference = "Stop"

try
{
    Import-Module -Force -DisableNameChecking .\psm\aes
    Import-Module -Force -DisableNameChecking .\psm\aws
    Import-Module -Force -DisableNameChecking .\psm\ansible
    Import-Module -Force -DisableNameChecking .\psm\slack

    if ($Roles.Length -eq 0)
    {
        $Roles = Get-DefaultRoles core
    }

    Test-SecretsAvailable
    Test-AwsCli
    Test-Slack
    Test-Environment core $Environment
    Test-Roles core $Roles $True

    $AccountId = Get-AccountId
    $RegionId = Get-RegionId

    foreach ($Role in $Roles)
    {
        if ($Role -eq "signaling" -Or $Role -eq "demo")
        {
            Upload-Folder $Environment $Role
        }
        else
        {
            Upload-Jar $Environment $Role
        }
    }

    Restart-Environment $Environment

    Write-Host ""
}
catch
{
    $Error = $Error[0]
    $StackTrace = $Error.ScriptStackTrace.Replace("`n", "`n`t")
    $Statement = $Error.InvocationInfo.PositionMessage
    
    Write-Host -ForegroundColor Red "`nFATAL ERROR: $($_.Exception.Message)"
    Write-Host -ForegroundColor Red $Statement
    Write-Host -ForegroundColor Red "`nStack trace:`n`t$StackTrace"
    
    $Leaf = Split-Path -Leaf $PWD
    while ($Leaf -ne "scripts")
    {
        Set-Location (Split-Path -Path $PWD -Parent)
        $Leaf = Split-Path -Leaf $PWD
    }
    
    Exit
}
