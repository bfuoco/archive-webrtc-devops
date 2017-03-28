function Test-RoleGroup
{
    [CmdletBinding()]
    Param([string]$RoleGroup)

    if ($RoleGroup -ne "core" -And $RoleGroup -ne "meta")
    {
        Write-Host ""
        throw "Invalid role group $RoleGroup."
    }
}

function Test-Roles
{
    [CmdletBinding()]
    Param([string]$RoleGroup, [string[]]$Roles)
    
    switch ($RoleGroup)
    {
        "core"
        {
            $ValidRoles = @("auth", "signaling", "media", "recording", "demo")
        }
        "meta"
        {
            $ValidRoles = @("teamcity")
        }
        default
        {
            Write-Host ""
            throw "Invalid role group $RoleGroup."
        }
    }
    
    if ($Roles.Length -eq 0)
    {
        Write-Host ""
        throw "No roles were specified."
    }
    
    foreach ($Role in $Roles)
    {
        if (-Not $ValidRoles.Contains($Role))
        {
            Write-Host
            throw "Role $Role is not in the $RoleGroup role group."
        }
    }
        
    $Chk = [char]8730
    
    Write-Host "`nBuilding AMIs for the following roles:"
    foreach ($Role in $ValidRoles)
    {
        if ($Roles.Contains($Role))
        {
            Write-Host "`t$Chk $Role"
        }
        else
        {
            Write-Host -ForegroundColor DarkGray "`t  $Role"
        }
    }   
}

function Test-Environment
{
    [CmdletBinding()]
    Param([string]$RoleGroup, [string]$Environment)

    Write-Host "`nChecking build configuration for role group:"
    Write-Host -ForegroundColor DarkGray "`tRole group  : $RoleGroup"
    
    if ($RoleGroup -eq "core")
    {
        if (-Not $("development", "integrated", "staging", "qa", "production").Contains($Environment))
        {
            Write-Host ""
            throw "Invalid environment $Environment."
        }
        
        Write-Host -ForegroundColor DarkGray "`tEnvironment : $Environment"
    }
    elseif ($RoleGroup -eq "meta")
    {
        Write-Host -ForegroundColor DarkGray "`tEnvironment : <<none>>"
    }
}

function Get-DefaultRoles
{
    [CmdletBinding()]
    Param([string]$RoleGroup)
    
    if ($RoleGroup -eq "core")
    {
        return @("auth", "media", "signaling", "recording", "demo")
    }
    elseif ($RoleGroup -eq "meta")
    {
        return @("teamcity")
    }
}

Export-ModuleMember -function Test-RoleGroup
Export-ModuleMember -function Test-Roles
Export-ModuleMember -function Test-Environment
Export-ModuleMember -function Get-DefaultRoles
