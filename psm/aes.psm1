function Test-SecretsAvailable
{
    if (-Not (Test-Path secrets.txt))
    {
        throw " `nSecrets file does not exist."
    }
    
    $Lines = Get-Content secrets.txt
    foreach ($Line in $Lines)
    {
        if ([string]::IsNullOrWhiteSpace($Line))
        {
            continue;
        }
        
        $Path = $Line
        $PathExists = Test-Path $Path
        
        if (-Not $PathExists)
        {
            throw "Secrets have not been decrypted. Run the decrypt command."
        }
    }
}

<#
Converts a secure string to a regular string.
#>
function Convert-SecureString
{
    Param([SecureString]$Value)
    
    if ($Value -eq $Null)
    {
        throw "Value cannot be null."
    }
    
    [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value))
}

<#
Converts a byte array to a base-16 string.
#>
function Get-HexString
{
    Param([byte[]]$Data)
    
    ([BitConverter]::ToString($Data)).ToLower().Replace("-", "")
}

<#
Removes trailing null characters from a byte array.
#>
function Remove-NullTerminators
{
    Param([byte[]]$Data)
    
    for ($i = $Data.Length - 1; $i -gt 0; $i--)
    {
        if ($Data[$i] -ne 0x00)
        {
            break;
        }
    }
    
    $Size = $i + 1
    $DataTrimmed = New-Object byte[] $Size
    
    [Buffer]::BlockCopy($Data, 0, $DataTrimmed, 0, $Size)
    
    $DataTrimmed
}

<#
Gets the passphrase used to encrypt/decrypt secrets.
#>
function Get-Passphrase
{
    Param([bool]$Force)
    $WebrtcAppData = "$($Env:LOCALAPPDATA)\Webrtc"
    $WebrtcKeyFile = "$WebrtcAppData\webrtc-passphrase-key"
    $WebrtcPassphraseEncrypted = $Env:WEBRTC_PASSPHRASE_ENCRYPTED
    
    $ExpectedPassphraseHashBase16 = [IO.File]::ReadAllLines("$PWD/secrets.sha256")
    
    if (-Not [string]::IsNullOrWhiteSpace($WebrtcPassphraseEncrypted))
    {
        Write-Host "`nAttempting to retrieve cached passphrase."
        
        try
        {
            if (-Not (Test-Path $WebrtcKeyFile))
            {
                throw "No key file at $WebrtcKeyFile"
            }
            
            $PassphraseKeyBytes = [IO.File]::ReadAllBytes($WebrtcKeyFile)
            
            $PassphraseSecretWithHashAndIVBase64 = $Env:WEBRTC_PASSPHRASE_ENCRYPTED
            $PassphraseSecretWithHashAndIVBytes = [Convert]::FromBase64String($PassphraseSecretWithHashAndIVBase64)
            $PassphraseHashBytes = $PassphraseSecretWithHashAndIVBytes[0..31]
            $PassphraseIVBytes = $PassphraseSecretWithHashAndIVBytes[32..47]
            
            $Aes = New-Object Security.Cryptography.AesManaged
            $Aes.Mode = [Security.Cryptography.CipherMode]::CBC
            $Aes.Padding = [Security.Cryptography.PaddingMode]::Zeros
            $Aes.BlockSize = 128
            $Aes.KeySize = 256
            $Aes.Key = $PassphraseKeyBytes
            $Aes.IV = $PassphraseIVBytes
            
            $Decryptor = $Aes.CreateDecryptor();
            $PassphraseBytes = $Decryptor.TransformFinalBlock($PassphraseSecretWithHashAndIVBytes, 48, $PassphraseSecretWithHashAndIVBytes.Length - 48);
            $PassphraseBytes = Remove-NullTerminators $PassphraseBytes
            
            $Sha256 = [Security.Cryptography.HashAlgorithm]::Create("SHA256")
            $CheckHashBytes = $Sha256.ComputeHash($PassphraseBytes);
            
            $Aes.Dispose()
            $Sha256.Dispose()
            $Decryptor.Dispose()

            if ((Compare-Object $PassphraseHashBytes $CheckHashBytes).Length -gt 0)
            {
                throw "Could not decrypt the passphrase."
            }
            $PassphraseHashBase16 = Get-HexString $PassphraseHashBytes
            if ($PassphraseHashBase16 -ne $ExpectedPassphraseHashBase16)
            {
                throw "Cached passphrase did not match the expected passphrase. Removing from cache."
            }
            
            Write-Host "Passphrase retrieved successfully."
            [Text.Encoding]::UTF8.GetString($PassphraseBytes)
        }
        catch
        {
            Write-Host "Failure during decryption of cached passphrase. Clearing passphrase."
            Remove-Item Env:WEBRTC_PASSPHRASE_ENCRYPTED
            
            throw $_.Exception
        }
    }
    else
    {
        Write-Host "`nNo passphrase cached."

        $Passphrase = Read-Host -AsSecureString "`nEnter a passphrase"
        $PassphraseConfirm = Read-Host -AsSecureString "Confirm the passphrase"

        $Passphrase = Convert-SecureString $Passphrase
        $PassphraseConfirm = Convert-SecureString $PassphraseConfirm

        if ($Passphrase -ne $PassphraseConfirm)
        {
            throw "Passphrases do not match."
        }

        $PassphraseBytes = [Text.Encoding]::UTF8.GetBytes($Passphrase)
        
        $Sha256 = [Security.Cryptography.HashAlgorithm]::Create("SHA256")
        $PassphraseHashBytes = $Sha256.ComputeHash($PassphraseBytes);
        $PassphraseHashBase16 = Get-HexString $PassphraseHashBytes
        $PassphraseHashBase16Bytes = [Text.Encoding]::UTF8.GetBytes($PassphraseHashBase16)
        
        if (-Not $Force)
        {
            $PassphraseHashBase16 = Get-HexString $PassphraseHashBytes
            if ($PassphraseHashBase16 -ne $ExpectedPassphraseHashBase16)
            {
                throw "Passphrase did not match the expected passphrase. Run this command again with the -Force parameter to override this."
            }
        }
        
        $Sha256.Dispose()
        
        [IO.File]::WriteAllBytes("$PWD/secrets.sha256", $PassphraseHashBase16Bytes)
        
        $Aes = New-Object Security.Cryptography.AesManaged
        $Aes.Mode = [Security.Cryptography.CipherMode]::CBC
        $Aes.Padding = [Security.Cryptography.PaddingMode]::Zeros
        $Aes.BlockSize = 128
        $Aes.KeySize = 256

        New-Item -ItemType Directory -Force $WebrtcAppData | Out-Null
        [IO.File]::WriteAllBytes($WebrtcKeyFile, $Aes.Key)
     
        $Encryptor = $Aes.CreateEncryptor()
        $PassphraseSecretBytes = $Encryptor.TransformFinalBlock($PassphraseBytes, 0, $PassphraseBytes.Length)
        $PassphraseSecretWithHashAndIVBytes = $PassphraseHashBytes + $Aes.IV + $PassphraseSecretBytes
        
        $Aes.Dispose()
        $Encryptor.Dispose()       
        
        $PassphraseSecretWithHashAndIVBase64 = [Convert]::ToBase64String($PassphraseSecretWithHashAndIVBytes)
        
        [Environment]::SetEnvironmentVariable("WEBRTC_PASSPHRASE_ENCRYPTED", $PassphraseSecretWithHashAndIVBase64, "User")
        [Environment]::SetEnvironmentVariable("WEBRTC_PASSPHRASE_ENCRYPTED", $PassphraseSecretWithHashAndIVBase64, "Process")
        
        $Passphrase
    }
}

<#
Gets an array of files that should be encrypted, based on the values in the secrets.txt file.
#>
function Get-FilesToEncrypt
{
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
        
        if ($PathExists)
        {
            $Files.Add($Path)
        }
    }
    
    $Files
}

<#
Gets an array of files that should be encrypted, based on the values in the secrets.txt file.
#>
function Get-FilesToDecrypt
{
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
        
        if ($EncryptedPathExists)
        {
            $Files.Add($Path)
        }
    }
    
    $Files
}

<#
Encrypts a file with the provided passphrase.

The passphrase is encoded using PDKDF2 to create an 256-bit AES encryption key. If an encrypted
file already exists, the the hash of the current file will be checked against that of the
encrypted file. If there are no changes, the file will not be re-encrypted.
#>
function Encrypt-File
{
    Param([string]$File, [string]$Passphrase, [bool]$Force)
    
    $FilePath = "$PWD\$File"    
    Write-Host -NoNewLine "Encrypting $($File): "
    
    $DataBytes = [IO.File]::ReadAllBytes($FilePath)
    $PassphraseBytes = [Text.Encoding]::UTF8.GetBytes($Passphrase)
    $SaltBytes = New-Object Byte[] @(8)
    
    $Sha256 = [Security.Cryptography.HashAlgorithm]::Create("SHA256")
    $HashBytes = $Sha256.ComputeHash($DataBytes);
    
    if (-Not $Force) 
    {
        if (Test-Path "$FilePath.encrypted")
        {
            $CheckBytes = [IO.File]::ReadAllBytes("$FilePath.encrypted")
            $CheckHashBytes = $CheckBytes[0..31]
            
            if ((Compare-Object $HashBytes $CheckHashBytes).Length -eq 0)
            {
                Write-Host "skipped"
                return
            }
        }
    }
        
    $Rng = New-Object Security.Cryptography.RNGCryptoServiceProvider
    $Rng.GetBytes($SaltBytes)
    
    $Pbkdf2 = New-Object Security.Cryptography.Rfc2898DeriveBytes @($PassphraseBytes, $SaltBytes, 65536)
    $KeyBytes = $Pbkdf2.GetBytes(16)
    
    $Aes = New-Object Security.Cryptography.AesManaged
    $Aes.Mode = [Security.Cryptography.CipherMode]::CBC
    $Aes.Padding = [Security.Cryptography.PaddingMode]::Zeros
    $Aes.BlockSize = 128
    $Aes.KeySize = 256
    $Aes.Key = $KeyBytes
    
    $Encryptor = $Aes.CreateEncryptor()
    $DataSecretBytes = $Encryptor.TransformFinalBlock($DataBytes, 0, $DataBytes.Length)
    $DataSecretWithHashAndIVAndSaltBytes = $HashBytes + $Pbkdf2.Salt + $Aes.IV + $DataSecretBytes
    
    $Rng.Dispose()
    $Sha256.Dispose()
    $Aes.Dispose()
    $Pbkdf2.Dispose()
    
    [IO.File]::WriteAllBytes("$PWD\$File.encrypted", $DataSecretWithHashAndIVAndSaltBytes)
    
    Write-Host "complete"
}

<#
Decrypts a file with the provided passphrase.

The encryption key is derived using PDKDF2. The salt and IV are prepended to the cipher text.
After decryption, a hash comparison will be performed. If the hash does not match the original
data, then the operation will terminate with an error.
#>
function Decrypt-File
{
    Param([string]$File, [string]$Passphrase)
    
    $FilePath = "$PWD\$File"
    Write-Host -NoNewLine "Decrypting $File.encrypted: "
    
    $DataSecretWithHashAndIVAndSaltBytes = [IO.File]::ReadAllBytes("$FilePath.encrypted")
    
    $PassphraseBytes = [Text.Encoding]::UTF8.GetBytes($Passphrase)
    $HashBytes = $DataSecretWithHashAndIVAndSaltBytes[0..31]
    $SaltBytes = $DataSecretWithHashAndIVAndSaltBytes[32..39]
    $IVBytes = $DataSecretWithHashAndIVAndSaltBytes[40..55]
   
    $Pbkdf2 = New-Object Security.Cryptography.Rfc2898DeriveBytes @($PassphraseBytes, $SaltBytes, 65536)
    $KeyBytes = $Pbkdf2.GetBytes(16)
    
    $Aes = New-Object Security.Cryptography.AesManaged
    $Aes.Mode = [Security.Cryptography.CipherMode]::CBC
    $Aes.Padding = [Security.Cryptography.PaddingMode]::Zeros
    $Aes.BlockSize = 128
    $Aes.KeySize = 256
    $Aes.Key = $KeyBytes
    $Aes.IV = $IVBytes

    $Decryptor = $Aes.CreateDecryptor();
    $DataBytes = $Decryptor.TransformFinalBlock($DataSecretWithHashAndIVAndSaltBytes, 56, $DataSecretWithHashAndIVAndSaltBytes.Length - 56);
    
    for ($i = $DataBytes.Length - 1; $i -gt 0; $i--)
    {
        if ($DataBytes[$i] -ne 0x00)
        {
            break;
        }
    }
    
    $DataSize = $i + 1
    $DataBytesTrimmed = New-Object byte[] $DataSize
    
    [Buffer]::BlockCopy($DataBytes, 0, $DataBytesTrimmed, 0, $DataSize)
    
    $Sha256 = [Security.Cryptography.HashAlgorithm]::Create("SHA256")
    $CheckHashBytes = $Sha256.ComputeHash($DataBytesTrimmed);
    
    if ((Compare-Object $HashBytes $CheckHashBytes).Length -gt 0)
    {
        throw "Invalid passphrase was entered."
    }        
   
    $Sha256.Dispose()
    $Aes.Dispose()
    $Pbkdf2.Dispose()
    
    [IO.File]::WriteAllBytes("$PWD\$File", $DataBytesTrimmed)
    
    Write-Host "complete"
}

Export-ModuleMember -function Test-SecretsAvailable
Export-ModuleMember -function Convert-SecureString
Export-ModuleMember -function Get-Passphrase
Export-ModuleMember -function Get-FilesToEncrypt
Export-ModuleMember -function Get-FilesToDecrypt
Export-ModuleMember -function Encrypt-File
Export-ModuleMember -function Decrypt-File
