<#
The decrypt function decrypts secret files that are stored int he repository. The secrets.txt file contains a list
of paths to secrets that should be encrypted.

Secrets will be decrypted from files with the ".encrypted" extension. Decrypted files will be stored in the same
location as the encrypted file.

Upon first decrypting files, you will be prompted to enter a passphrase. This passphrase will be used to generate the
256-bit key for encryption.

A randomly generated key will then be created and stored in the $Env:LOCALAPPDATA\Orbba folder. This key will be used to
encrypt the passphrase, which will be stored in an environment variable. On subsequent executions of the decrypt
function, you will no longer be prompted to enter the passphrase.

This is a shared passphrase between all users of the repository.
#>
$ErrorActionPreference = "Stop"

try
{
    Import-Module -Force -DisableNameChecking .\psm\aes

    $Files = Get-FilesToDecrypt
    if ($Files.Length -eq 0)
    {
        Write-Host "No files to decrypt.`n"
        Exit
    }
    
    Write-Host ""

    $Passphrase = Read-Host -AsSecureString "Enter a passphrase"
    $PassphraseConfirm = Read-Host -AsSecureString "Confirm the passphrase"

    $Passphrase = Convert-SecureString $Passphrase
    $PassphraseConfirm = Convert-SecureString $PassphraseConfirm

    if ($Passphrase -ne $PassphraseConfirm)
    {
        throw "Passphrases do not match."
    }
    
    Write-Host ""
    foreach ($File in $Files)
    {
        Decrypt-File $File $Passphrase
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
    Exit 
}