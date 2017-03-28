<#
Tests whether or not the AWS CLI tools are installed.
#>
function Test-AwsCli
{
    Write-Host "`nChecking AWS CLI tools installation:"

    $AwsLocation = Get-Command "aws" -ErrorAction "SilentlyContinue"
    if (-Not ($AwsLocation))
    {
        throw "AWS CLI tools are not installed or are not in PATH."
    }
    
    Write-Host -ForegroundColor DarkGray "`tLocation : $($AwsLocation.Source)"
    
    Write-Host "`nChecking AWS CLI environment variables:"
    if (Test-Path Env:AWS_DEFAULT_REGION)
    {
        Write-Host -ForegroundColor DarkGray "`tAWS_DEFAULT_REGION    : $Env:AWS_DEFAULT_REGION"
    }
    else
    {
        throw "Environment variable AWS_DEFAULT_REGION is not set."
    }
    
    if (Test-Path Env:AWS_ACCESS_KEY_ID)
    {
        Write-Host -ForegroundColor DarkGray "`tAWS_ACCESS_KEY_ID     : $Env:AWS_ACCESS_KEY_ID"
    }
    else
    {
        throw "Environment variable AWS_ACCESS_KEY_ID is not set."
    }

    if (Test-Path Env:AWS_SECRET_ACCESS_KEY)
    {
        Write-Host -ForegroundColor DarkGray "`tAWS_SECRET_ACCESS_KEY : <<hidden>>"
    }
    else
    {
        throw "Environment variable AWS_SECRET_ACCESS_KEY variable is not set."
    }

    $AwsExpression = "aws sts get-caller-identity"

    Write-Host "`nChecking AWS credentials:"
    Write-Host "Using AWS command: $AwsExpression"

    $Result = Invoke-Expression $AwsExpression
    if ($LastExitCode -ne 0)
    {
        throw "Your AWS credentials are invalid."
    }
}

<#
Gets the current region ID as set in the environment variables.
#>
function Get-RegionId
{
    $Env:AWS_DEFAULT_REGION
}

<#
Gets the name of the current region ID as set in the environment variables.
#>
function Get-RegionName
{
    $RegionId = $Env:AWS_DEFAULT_REGION
    $RegionId = $RegionId.ToLower()
    
    switch ($RegionId)
    {
        "us-west-1"
        {
            $Name = "US West (N. California)"
        }
        "us-west-2"
        {
            $Name = "US West (Oregon)"
        }
        default
        {
            throw "Unknown region $RegionId"
        }
    }
    
    Write-Host "`nAWS region identified:"
    Write-Host -ForegroundColor DarkGray "`tId   : $RegionId"
    Write-Host -ForegroundColor DarkGray "`tName : $Name"
    
    $Name
}

<#
Gets the ID of the AMI of the most recent Ubuntu 14.04 build.
#>
function Get-UbuntuAmiId
{
    $Filters = """Name=architecture,Values=x86_64"" ""Name=virtualization-type,Values=hvm"" ""Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd*"""

    $AwsExpression = "aws ec2 describe-images --filters $Filters --query ""reverse(sort_by(Images[*], &CreationDate))[0].[ImageId, Name, CreationDate]"" --output text"

    Write-Host "`nRetrieving ID of most recent Ubuntu AMI:"
    Write-Host "Using AWS command: $AwsExpression"
    
    $UbuntuAmiInfo = (Invoke-Expression $AwsExpression)
    if ($LastExitCode -ne 0)
    {
        throw "Could not retrieve Ubuntu AMI Id."
    }
    elseif ($UbuntuAmiInfo -eq $Null -Or $UbuntuAmiInfo -eq "None")
    {
        throw "Could not retrieve Ubuntu AMI Id."
    }

    $UbuntuAmiInfo = $UbuntuAmiInfo.Split("`t")

    Write-Host -ForegroundColor DarkGray "`tId      : $($UbuntuAmiInfo[0])"
    Write-Host -ForegroundColor DarkGray "`tName    : $($UbuntuAmiInfo[1])"
    Write-Host -ForegroundColor DarkGray "`tCreated : $($UbuntuAmiInfo[2])"

    $UbuntuAmiInfo[0]
}

<#
Gets the amazon account id of the current user.
#>
function Get-AccountId
{
    $AwsExpression = "aws sts get-caller-identity --query ""Arn"" --output text"
    
    Write-Host "`nRetrieving account information from Amazon Web Services:"
    Write-Host "`Using AWS command: $AwsExpression"

    $AccountInfo = (Invoke-Expression $AwsExpression).Split(":")

    Write-Host -ForegroundColor DarkGray "`tAccountId : $($AccountInfo[4])"
    Write-Host -ForegroundColor DarkGray "`tUsername  : $($AccountInfo[5])"

    $AccountInfo[4]
}

<#
Copies the AMI ID for a role to its terraform configuration.
#>
function Copy-AmiId
{
    Param([string]$AccountId, [string]$RoleGroup, [string]$Role, [string]$Environment)

    if ($RoleGroup -eq "core")
    {
        $RoleName = "$($RoleGroup):$($Role):$($Environment)"
        $Filters = """Name=tag:Role,Values=$Role"" ""Name=tag:Environment,Values=$Environment"""
        $OutPath = "terraform\$RoleGroup\main-$Environment\variables_$($Role)_override.tf"
        $OutFile = "$($PWD)\$OutPath"
    }
    elseif ($RoleGroup -eq "meta")
    {
        $RoleName = "$($RoleGroup):$($Role)"
        $Filters = """Name=tag:Role,Values=$Role"""
        $OutPath = "terraform\$RoleGroup\main\variables_$($Role)_override.tf"
        $OutFile = "$($PWD)\$OutPath"
    }

    $AwsExpression = "aws ec2 describe-images --owners $AccountId --filters $Filters --query ""reverse(sort_by(Images[*], &CreationDate))[0].ImageId"" --output text"

    Write-Host "`nRetrieving most recent AMI for $RoleName from Amazon Web Services."
    Write-Host "Using AWS command: $AwsExpression"

    $AmiId = Invoke-Expression $AwsExpression
    if ($LastExitCode -ne 0)
    {
        throw "An error occurred while querying an AMI image from AWS."
    }

    if ($AmiId -eq $Null -Or $AmiId -eq "None")
    {
        Write-Host "No AMI found for $RoleName."
        return
    }

    Write-Host "`Found AMI for $($RoleName):"
    Write-Host -ForegroundColor DarkGray "`tRole     : $RoleName"
    Write-Host -ForegroundColor DarkGray "`tId       : $AmiId"
    Write-Host -ForegroundColor DarkGray "`tOverride : $OutPath"

    [IO.File]::WriteAllLines($OutFile, "variable $($Role)_ami_id {`n  type = ""string""`n  default = ""$AmiId""`n}")
}

<#
Copies the id of the meta VPC to the terraform configuration for other environments.
#>
function Copy-VpcId
{
    Param([string]$Environment)

    Write-Host "`nRetrieving ID of the meta VPC from Amazon Web Services."

    $AwsCmd = "aws ec2 describe-vpcs --filters Name=tag:RoleGroup,Values=meta --query ""Vpcs[0].[VpcId, CidrBlock]"" --output text"
    Write-Host "Using AWS command: $AwsCmd"

    $VpcInfo = Invoke-Expression $AwsCmd
    if ($LastExitCode -ne 0)
    {
        throw "Could not copy VPC info for the meta role group."
    }
    elseif ($VpcInfo -eq $Null -Or $VpcInfo -eq "None")
    {
        throw "No VPCs in the meta role group were found."
    }

    $VpcInfo = $VpcInfo.Split("`t")
    $OutPath = "terraform\core\main-$($Environment)\variables_meta_override.tf"
    $OutFile = "$($PWD)\$OutPath"

    Write-Host -ForegroundColor DarkGray "`tId       : $($VpcInfo[0])"
    Write-Host -ForegroundColor DarkGray "`tCidr     : $($VpcInfo[1])"
    Write-Host -ForegroundColor DarkGray "`tOverride : $OutPath"

    [IO.File]::WriteAllLines($OutFile, "variable meta_vpc_id {`n  type = ""string""`n  default = ""$($VpcInfo[0])""`n}")
}

function Upload-Jar
{
    Param([string]$Environment, [string]$Role)

    Write-Host "`nUploading jar for $Role"

    $AwsCmd = "aws s3 cp ../out/artifacts/$Role.jar s3://orbba-webrtc/core/$Environment/$Role.jar"
    Write-Host "Using AWS command: $AwsCmd"

    Invoke-Expression $AwsCmd
    if ($LastExitCode -ne 0)
    {
        throw "Could not upload the $Role JAR file."
    }
}

function Upload-Folder
{
    Param([string]$Environment, [string]$Role)

    Write-Host "`nSyncing directory for $Role"

    $AwsCmd = "aws s3 sync ../services/signaling s3://orbba-webrtc/core/$Environment/$Role --size-only --delete"
    Write-Host "Using AWS command: $AwsCmd"

    Invoke-Expression $AwsCmd
    if ($LastExitCode -ne 0)
    {
        throw "Could not sync the $Role directory."
    }
}

function Restart-Environment
{
    Param([string]$Environment)

    Write-Host "`nRetrieving active instances."

    $AwsCmd = "aws ec2 describe-instances --filter ""Name=tag:Environment,Values=$Environment"" --query ""Reservations[*].Instances[*].[InstanceId, Tags[?Key=='Role'].Value]"" --output text"
    Write-Host "Using AWS command: $AwsCmd"

    $InstanceInfo = Invoke-Expression $AwsCmd
    if ($LastExitCode -ne 0)
    {
        throw "Could not upload the $Role JAR file."
    }

    $InstanceIds = @(0) * ($InstanceInfo.Length / 2)

    Write-Host "`nRestarting the following machines:"
    for ($i = 0; $i -lt $InstanceInfo.Length; $i += 2)
    {
        $InstanceId = $InstanceInfo[$i]
        $InstanceRole = $InstanceInfo[$i + 1]

        $InstanceIds[$i / 2] = $InstanceId
        Write-Host "`t$InstanceId - $InstanceRole"
    }

    $InstanceIds = $InstanceIds -Join " "

    $AwsCmd = "aws ec2 reboot-instances --instance-ids $InstanceIds"
    Write-Host "`nUsing AWS command: $AwsCmd"
    Invoke-Expression $AwsCmd
}

Export-ModuleMember -function Test-AwsCli
Export-ModuleMember -function Get-RegionId
Export-ModuleMember -function Get-RegionName
Export-ModuleMember -function Get-UbuntuAmiId
Export-ModuleMember -function Get-AccountId
Export-ModuleMember -function Copy-AmiId
Export-ModuleMember -function Copy-VpcId
Export-ModuleMember -function Upload-Jar
Export-ModuleMember -function Upload-Folder
Export-ModuleMember -function Restart-Environment
