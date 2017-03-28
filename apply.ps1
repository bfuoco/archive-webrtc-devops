<#
Applies the AWS infrastructure for a role group using terraform.
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

    Test-SecretsAvailable
    Test-Terraform
    Test-AwsCli
    Test-Slack
    Test-RoleGroup $RoleGroup
    Test-Environment $RoleGroup $Environment

    $AccountId = Get-AccountId
    $RegionId = Get-RegionId

    if ($RoleGroup -eq "core")
    {
        Copy-VpcId $Environment
    }

    Apply-Infrastructure $RegionId $RoleGroup $Environment

    if ($RoleGroup -eq "core")
    {
        Send-Notification "Orbblob" (Get-SuccessEmoji) "Infrastructure was created for core roles in $Environment environment."
    }
    elseif ($RoleGroup -eq "meta")
    {
        Send-Notification "Orbblob" (Get-SuccessEmoji) "Infrastructure was created for meta roles."
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
