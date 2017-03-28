<#
#>
function Test-Aes
{
    [CmdletBinding()]
    Param()

    Write-Host "`nChecking for AES environment variables:"
    if (Test-Path Env:ORBBA_AES256_KEY)
    {
        Write-Host -ForegroundColor DarkGray "`tORBBA_AES256_KEY : <<hidden>>"
    }
    else
    {
        Write-Host ""
        throw "Environment variable ORBBA_AES256_KEY is not set."
    }
}

function Test-Key
{
    [CmdletBinding()]
    Param([string]$Key)

    $KeyBytes = [System.Convert]::FromBase64String($Key)

    $Sha256 = [Security.Cryptography.HashAlgorithm]::Create("SHA256")
    $Sha256Bytes = $Sha256.ComputeHash($KeyBytes);
    $Sha256Hash = -Join ($Sha256Bytes | ForEach {"{0:x2}" -f $_})
    
    $ExpectedHash = "7ed9bba99a6f92fbf7a9f00ccae21d9cf65c0571e8b91afc6a10139c284a15be"
    if ($Sha256Hash -eq $ExpectedHash)
    {
        Write-Host "`nKey matches expected SHA256 hash."
        Write-Host -ForegroundColor DarkGray "`tHash     : $Sha256Hash"
        Write-Host -ForegroundColor DarkGray "`tExpected : $ExpectedHash"
    }
    else
    {
        Write-Host "`nKey does not match expected SHA256 hash."
        Write-Host -ForegroundColor DarkGray "`tHash     : $Sha256Hash"
        Write-Host -ForegroundColor DarkGray "`tExpected : $ExpectedHash"
        
        Write-Host ""
        throw "Key specified in ORBBA_AES256_KEY does not match expected SHA256 hash."
    }   
}

<#
Gets an array of files that are considered "secret" - files that should be encrypted when committed
to the repository.

An error will be thrown if the secrets file doesn't exist or if any of the files listed in the
secrets file do not exist.

Returns an array of secret files.
#>
function Get-SecretFiles
{
    $ErrorActionPreference = "Stop"
    
    if (-Not (Test-Path secrets.txt))
    {
        throw " `nSecrets file does not exist."
    }
    
    $Files = New-Object Collections.Generic.List[string]
    $Lines = Get-Content secrets.txt
    
    foreach ($Line in $Lines)
    {
        if ([string]::IsNullOrWhiteSpace($Line))
        {
            continue;
        }
        
        $Path = $Line
        $EncryptedPath = "$Line.encrypted"
        
        $PathExists = Test-Path $Path
        $EncryptedPathExists = Test-Path $EncryptedPath
        
        if (-Not $PathExists -And -Not $EncryptedPathExists)
        {
            throw " `nSecrets file $Line does not exist."
        }
        
        $Files.Add($Path)
    }
    
    $Files
}

<#
Checks whether or not a secret file is encrypted.

Returns whether or not the file is encrypted.
#>
function Check-Encrypted
{
    Param([string]$File)
    $ErrorActionPreference = "Stop"
    
    Write-Host -NoNewLine "Checking $($File): " 
    
    if (Test-Path $File)
    {
        Write-Host "not encrypted"
        $False
    }
    else
    {
        if (Test-Path "$File.encrypted")
        {
            Write-Host "encrypted"
            $True
        }
        else
        {
            throw " `nCould not find $File."
        }
    }
}

function Encrypt-File
{
    [CmdletBinding()]
    Param([string]$File, [string]$Key)
    
    $Secret = (Get-Content $File) -Join "`n"
    $SecretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    
    $KeyBytes = [System.Convert]::FromBase64String($Key)

    $Aes = New-Object "System.Security.Cryptography.AesManaged"
    $Aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $Aes.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $Aes.BlockSize = 128
    $Aes.KeySize = 256
    $Aes.Key = $KeyBytes

    $Encryptor = $Aes.CreateEncryptor()
    $SecretEncrypted = $Encryptor.TransformFinalBlock($SecretBytes, 0, $SecretBytes.Length)
    $SecretEncryptedWithIV = $Aes.IV + $SecretEncrypted

    $Aes.Dispose()
    $SecretBase64 = [System.Convert]::ToBase64String($SecretEncryptedWithIV)

    Write-Host "Encrypting to: $File.encrypted"
    [System.IO.File]::WriteAllLines("$PWD\$File.encrypted", $SecretBase64)

    Remove-Item "$File"
}

function Decrypt-File
{
    Param([string]$File, [string]$Key)
    $ErrorActionPreference = "Stop"

    $SecretEncryptedBase64 = Get-Content "$File.encrypted"
    $SecretEncryptedBytes = [System.Convert]::FromBase64String($SecretEncryptedBase64)

    $KeyBytes = [System.Convert]::FromBase64String($Key)
    
    $IV = $SecretEncryptedBytes[0..15]

    $Aes = New-Object "System.Security.Cryptography.AesManaged"
    $Aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $Aes.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $Aes.BlockSize = 128
    $Aes.KeySize = 256
    $Aes.Key = $KeyBytes
    $Aes.IV = $IV

    $Decryptor = $Aes.CreateDecryptor();
    $Secret = $Decryptor.TransformFinalBlock($SecretEncryptedBytes, 16, $SecretEncryptedBytes.Length - 16);
    $Aes.Dispose()

    $SecretPlainText = [System.Text.Encoding]::UTF8.GetString($Secret).Trim([char]0)

    Write-Host "Decrypting to: $File"
    [System.IO.File]::WriteAllLines("$PWD\$File", "$SecretPlainText")

    #Remove-Item "$File.encrypted"
}

Export-ModuleMember -function Test-Aes
Export-ModuleMember -function Test-Key
Export-ModuleMember -function Get-SecretFiles
Export-ModuleMember -function Check-Encrypted
Export-ModuleMember -function Encrypt-File
Export-ModuleMember -function Decrypt-File
