Param(
    [Parameter(Mandatory = $True)]
    [String]
    $RoleGroup,

    [Parameter()]
    [String]
    $Environment,

    [Parameter()]
    [String[]]
    $Roles
)

$ErrorActionPreference = "Stop"

try
{
    Import-Module -Force -DisableNameChecking .\psm\aes
    Import-Module -Force -DisableNameChecking .\psm\aws
    Import-Module -Force -DisableNameChecking .\psm\ansible

    if ($Roles.Length -eq 0)
    {
        $Roles = Get-DefaultRoles $RoleGroup
    }

    if ([string]::IsNullOrWhiteSpace($Environment))
    {
        $Environment = "development"
    }

    Test-SecretsAvailable
    Test-AwsCli
    Test-RoleGroup $RoleGroup
    Test-Roles $RoleGroup $Roles $True
    Test-Environment $RoleGroup $Environment

    $AccountId = Get-AccountId
    $RegionId = Get-RegionId
    $RegionName = Get-RegionName

    foreach ($Role in $Roles)
    {
        Copy-AmiId $AccountId $RoleGroup $Role  $Environment
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
