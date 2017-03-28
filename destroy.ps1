<#
Destroys all of the managed infrastructure using terraform. Infrastructure that terraform
did not create will not be modified.
#>
Param(
    [Parameter(Mandatory = $True)]
    [String]
    $RoleGroup,

    [Parameter()]
    [String]
    $Environment
)

$ErrorActionPreference = "Stop"

try
{
    Import-Module -Force -DisableNameChecking .\psm\aws
    Import-Module -Force -DisableNameChecking .\psm\ansible
    Import-Module -Force -DisableNameChecking .\psm\terraform

    Test-Terraform
    Test-AwsCli
    Test-Slack
    Test-RoleGroup $RoleGroup
    Test-Environment $RoleGroup $Environment

    $AccountId = Get-AccountId

    Destroy-Infrastructure $RoleGroup $Environment

    if ($RoleGroup -eq "core")
    {
        Send-Notification "Testblob" (Get-SuccessEmoji) "Infrastructure was destroyed for core roles in $Environment environment."
    }
    elseif ($RoleGroup -eq "meta")
    {
        Send-Notification "Testblob" @(":skull:") "Infrastructure was destroyed for meta roles."
    }

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
