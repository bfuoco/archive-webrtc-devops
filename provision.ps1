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
    Import-Module -Force -DisableNameChecking .\psm\packer
    Import-Module -Force -DisableNameChecking .\psm\slack

    if ($Roles.Length -eq 0)
    {
        $Roles = Get-DefaultRoles $RoleGroup
    }

    if ([string]::IsNullOrWhiteSpace($Environment))
    {
        $Environment = "development"
    }

    Test-SecretsAvailable
    Test-Packer
    Test-AwsCli
    Test-Slack
    Test-RoleGroup $RoleGroup
    Test-Roles $RoleGroup $Roles
    Test-Environment $RoleGroup $Environment

    $AccountId = Get-AccountId
    $RegionId = Get-RegionId
    $RegionName = Get-RegionName
    $UbuntuAmiId = Get-UbuntuAmiId

    foreach ($Role in $Roles)
    {
        try
        {
            Build-Ami $RegionId $UbuntuAmiId $RoleGroup $Role $Environment
            Copy-AmiId $AccountId $RoleGroup $Role  $Environment

            if ($RoleGroup -eq "core")
            {
                Send-Notification "Testblob" (Get-SuccessEmoji) "A new AMI was created for core:$($Role):$($Environment)."
            }
            elseif ($RoleGroup -eq "meta")
            {
                Send-Notification "Testblob" (Get-SuccessEmoji) "A new AMI was created for meta:$($Role)."
            }
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
        }
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
