Param(
    [Parameter(Mandatory = $True)]
    [String]
    $RoleGroup,

    [Parameter()]
    [String[]]
    $Roles,

    [Parameter()]
    [String]
    $Environment
)

$ErrorActionPreference = "Stop"

Import-Module -Force -DisableNameChecking .\psm\aws
Import-Module -Force -DisableNameChecking .\psm\ansible
Import-Module -Force -DisableNameChecking .\psm\packer

if ($Roles.Length -eq 0)
{
    $Roles = Get-DefaultRoles $RoleGroup
}

if ([string]::IsNullOrWhiteSpace($Environment))
{
    $Environment = "development"
}

Test-Packer
Test-AwsCli
Test-RoleGroup $RoleGroup
Test-Roles $RoleGroup $Roles
Test-Environment $RoleGroup $Environment

$AccountId = Get-AccountId
$regionId = Get-RegionId
$RegionName = Get-RegionName
$UbuntuAmiId = Get-UbuntuAmiId

foreach ($Role in $Roles)
{
     Build-Ami $RegionId $UBuntuAmiId $RoleGroup $Role $Environment
}

$Amis = Get-AmiIds $AccountId $Environment

foreach ($Role in $Roles)
{
    if ($Amis.ContainsKey($Role))
    {
        Copy-AmiId $RoleGroup $Role $Amis.$Role.Id $Environment
    }
}

Write-Host ""
