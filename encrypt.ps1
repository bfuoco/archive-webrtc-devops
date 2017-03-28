<#
The encrypt function encrypts secret files so that they can be safely stored in the repository. The secrets.txt file
contains a list of paths to secrets that should be encrypted.

Secrets will be encrypted and stored in a file with the ".encrypted" extension appended to their file name. Encrypted
files will be stored in the same location as the original file.

Upon first encrypting files, you will be prompted to enter a passphrase. This passphrase will be used to generate the
256-bit key for encryption.

A randomly generated key will then be created and stored in the $Env:LOCALAPPDATA\Orbba folder. This key will be used to
encrypt the passphrase, which will be stored in an environment variable. On subsequent executions of the encrypt
function, you will no longer be prompted to enter your password.
#>
Param()
$ErrorActionPreference = "Stop"

Import-Module -Force -DisableNameChecking -Name "$PWD\psm\aes"

Test-Aes

$Key = $Env:ORBBA_AES256_KEY
Test-Key $Key

Write-Host ""

$Files = Get-SecretFiles
$FilesToEncrypt = @()
foreach ($File in $Files)
{
    $IsEncrypted = Check-Encrypted $File
    if (-Not $IsEncrypted)
    {
        $FilesToEncrypt += $File
    }
}

return

Write-Host ""
if ($FilesToEncrypt.Length -eq 0)
{
    Write-Host "No files to encrypt."
}

foreach ($File in $FilesToEncrypt)
{
    Encrypt-File $File $Key
}

Write-Host ""
