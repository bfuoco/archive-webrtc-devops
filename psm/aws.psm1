function Test-AwsCli
{
    $ErrorActionPreference = "Stop"

    Write-Host "`nChecking AWS CLI tools installation:"

    $AwsLocation = Get-Command "aws" -ErrorAction "SilentlyContinue"
    if (-Not ($AwsLocation))
    {
        Write-Host ""
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
        Write-Host ""
        throw "Environment variable AWS_DEFAULT_REGION is not set."
    }
    
    if (Test-Path Env:AWS_ACCESS_KEY_ID)
    {
        Write-Host -ForegroundColor DarkGray "`tAWS_ACCESS_KEY_ID     : $Env:AWS_ACCESS_KEY_ID"
    }
    else
    {
        Write-Host ""
        throw "Environment variable AWS_ACCESS_KEY_ID is not set."
    }

    if (Test-Path Env:AWS_SECRET_ACCESS_KEY)
    {
        Write-Host -ForegroundColor DarkGray "`tAWS_SECRET_ACCESS_KEY : <<hidden>>"
    }
    else
    {
        Write-Host ""
        throw "Environment variable AWS_SECRET_ACCESS_KEY variable is not set."
    }

    $AwsExpression = "aws sts get-caller-identity"

    Write-Host "`nChecking AWS credentials:"
    Write-Host "Using AWS command: $AwsExpression"

    $Result = Invoke-Expression $AwsExpression
    if ($LastExitCode -ne 0) {
        Write-Host ""
        throw "Your AWS credentials are invalid."
    }
}

function Get-RegionId
{
    $ErrorActionPreference = "Stop"

    $Env:AWS_DEFAULT_REGION
}

function Get-RegionName
{
    $ErrorActionPreference = "Stop"

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

function Get-UbuntuAmiId
{
    $ErrorActionPreference = "Stop"

    $AwsExpression = "aws ec2 describe-images --filters " +
        """Name=architecture,Values=x86_64"" " +
        """Name=virtualization-type,Values=hvm"" " +
        """Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64*"" "

    Write-Host "`nRetrieving ID of most recent Ubuntu AMI:"
    Write-Host "Using AWS command: $AwsExpression"
    
    $AmiDataJson = [string]::Join("", (Invoke-Expression $AwsExpression))
    $AmiData = ConvertFrom-Json $AmiDataJson;
    
    $MostRecent = $AmiData.Images[0]
    $MostRecentDate = Get-Date $AmiData.Images[0].CreationDate
    
    for ($i = 1; $i -lt $AmiData.Images.Length; $i++)
    {
        $CurrentDate = Get-Date $AmiData.Images[$i].CreationDate
        
        if ($CurrentDate -gt $MostRecentDate)
        {
            $MostRecent = $AmiData.Images[$i]
            $MostRecentDate = $CurrentDate
        }
    }
    
    Write-Host -ForegroundColor DarkGray "`tId      : $($MostRecent.ImageId)"
    Write-Host -ForegroundColor DarkGray "`tName    : $($MostRecent.Name)"
    Write-Host -ForegroundColor DarkGray "`tCreated : $($MostRecent.CreationDate)"

    $MostRecent.ImageId
}

function Get-AccountId
{
    $ErrorActionPreference = "Stop"

    $AwsExpression = "aws sts get-caller-identity"
    
    Write-Host "`nRetrieving account information from Amazon Web Services:"
    Write-Host "`Using AWS command: $AwsExpression"

    $UserDataJson = [string]::Join("", (Invoke-Expression $AwsExpression))
    $UserData = ConvertFrom-Json $UserDataJson;
    
    Write-Host -ForegroundColor DarkGray "`tAccount : $($UserData.Account)"
    Write-Host -ForegroundColor DarkGray "`tArn     : $($UserData.ARN)"
    
    $UserData.Account
}

function Get-AmiIds
{
    Param([string]$AccountId, [string]$Environment)
    $ErrorActionPreference = "Stop"

    $AwsExpression = "aws ec2 describe-images --owners $AccountId"
    
    Write-Host "`nRetrieving AMIs from Amazon Web Services."
    Write-Host "Using AWS command: $AwsExpression"

    $AmiDataJson = [string]::Join("", (Invoke-Expression $AwsExpression))
    $AmiData = ConvertFrom-Json $AmiDataJson;

    $Count = $AmiData.Images.Count;
    Write-Host "Found $Count image(s).`n"

    $Amis = @{}
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)

    foreach ($Image in $AmiData.Images)
    {
        $CurrentAmi = @{Id = $Image.ImageId; Name = $Image.Name; Date = Get-Date $Image.CreationDate}

        Write-Host "Processing image: $($CurrentAmi.Name)($($CurrentAmi.Id)), created: $($Image.CreationDate)"

        $Role = $Null
        foreach ($Tag in $Image.Tags)
        {
            if ($Tag.Key -eq "Role")
            {
                $Role = $Tag.Value
                
                Write-Host "Role tag found, image identified as ""$Role"" node."
                
                if ($Amis.ContainsKey($Role))
                {
                    if ($CurrentAmi.Date -gt $Amis.$Role.Date)
                    {
                        $Amis.$Role = $CurrentAmi;
                        Write-Host "Replacing previous role with newer AMI."
                    }
                    else
                    {
                        Write-Host "Ignoring older AMI."
                    }
                }
                else
                {
                    $Amis.Add($Role, $CurrentAmi)
                }
                
                break;
            }
        }

        if ($Role -eq $Null)
        {
            Write-Host "No role tag found, image is not an Orbba AMI, skipping."
        }

        Write-Host ""
    }
    
    $Amis
}

function Copy-AmiId
{
    Param([string]$RoleGroup, [string]$Role, [string]$AmiId, [string]$Environment)
    $ErrorActionPreference = "Stop"
    
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
    
    if ($RoleGroup -eq "core")
    {
        $OutFile = "$($PWD)\terraform\$RoleGroup\main-$Environment\variables_$($Role)_override.tf"
        Write-Host "Writing $Role AMI $($RoleData.Name)($AmiId) to $OutFile"

        [IO.File]::WriteAllLines($OutFile, "variable $($Role)_ami_id {`n  type = ""string""`n  default = ""$AmiId""`n}", $Utf8NoBomEncoding)
    }
    elseif ($RoleGroup -eq "meta")
    {
        $OutFile = "$($PWD)\terraform\$RoleGroup\main\variables_$($Role)_override.tf"
        Write-Host "Writing $Role AMI $($RoleData.Name)($AmiId) to $OutFile"

        [IO.File]::WriteAllLines($OutFile, "variable $($Role)_ami_id {`n  type = ""string""`n  default = ""$AmiId""`n}", $Utf8NoBomEncoding)
    }
    else
    {
        throw "Unknown role group."
    }
}

function Copy-VpcId
{
    Param([string]$Environment)
    $ErrorActionPreference = "Stop"

    Write-Host "`nRetrieving ID of meta VPC from Amazon Web Services."

    $AwsCmd =  "aws ec2 describe-vpcs --filters Name=tag:RoleGroup,Values=meta"
    Write-Host "Using AWS command: $AwsCmd"

    $VpcDataJson = [string]::Join("", (Invoke-Expression $AwsCmd))
    $VpcData = ConvertFrom-Json $VpcDataJson;

    $Count = $VpcData.Vpcs.Count;
    Write-Host "Found $Count vpcs(s).`n"

    if ($Count -gt 1)
    {
        Write-Host ""
        throw "Found more than one VPC for the meta role group."
    }
    elseif ($Count -eq 0)
    {
        Write-Host ""
        throw "Could not find a VPC for the meta role group."
    }

    $VpcId = $VpcData.Vpcs[0].VpcId

    $OutFile = "$($PWD)\terraform\core\main-$($Environment)\variables_meta_override.tf"
    Write-Host "Writing meta VPC ID $VpcId to $OutFile"

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)

    [IO.File]::WriteAllLines($OutFile, "variable meta_vpc_id {`n  type = ""string""`n  default = ""$VpcId""`n}", $Utf8NoBomEncoding)
}

Export-ModuleMember -function Test-AwsCli
Export-ModuleMember -function Get-RegionId
Export-ModuleMember -function Get-RegionName
Export-ModuleMember -function Get-UbuntuAmiId
Export-ModuleMember -function Get-AccountId
Export-ModuleMember -function Get-AmiIds
Export-ModuleMember -function Copy-AmiId
Export-ModuleMember -function Copy-VpcId
