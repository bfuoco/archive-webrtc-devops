Param(
    [Parameter(Mandatory = $True)]
    [String]
    $RoleGroup,

    [Parameter()]
    [String]
    $Environment
)

$ErrorActionPreference = "Stop"

Import-Module -Force -Name "$PWD\psm\aws"
Import-Module -Force -Name "$PWD\psm\ansible"
Import-Module -Force -Name "$PWD\psm\terraform"

Test-Terraform
Test-AwsCli
Test-RoleGroup $RoleGroup
Test-Environment $RoleGroup $Environment

$AccountId = Get-AwsAccountId
$RegionInfo = Get-AwsRegionInfo

if ($RoleGroup -eq "main")
{
    Copy-BuildVpcId $Environment
}

#Publish-Infrastructure $RegionInfo.Id $RoleGroup $Environment

Write-Host ""
