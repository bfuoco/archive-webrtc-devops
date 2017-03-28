<#
The encrypt function encrypts secret files so that they can be safely stored in the repository. The secrets.txt file
contains a list of paths to secrets that should be encrypted.

Secrets will be encrypted and stored in a file with the ".encrypted" extension appended to their file name. Encrypted
files will be stored in the same location as the original file.

Upon first encrypting files, you will be prompted to enter a passphrase. This passphrase will be used to generate the
256-bit key for encryption.

A randomly generated key will then be created and stored in the $Env:LOCALAPPDATA\Orbba folder. This key will be used to
encrypt the passphrase, which will be stored in an environment variable. On subsequent executions of the encrypt
function, you will no longer be prompted to enter the passphrase.

This is a shared passphrase between all users of the repository.
#>
Param(
    [Parameter()]
    [Alias("f")]
    [Switch]
    $Force
)

$ErrorActionPreference = "Stop"

try
{
    Import-Module -Force -DisableNameChecking .\psm\aes

    $Files = Get-FilesToEncrypt $Force
    if ($Files.Length -eq 0)
    {
        Write-Host "No files to encrypt.`n"
        Exit
    }
    
    $Passphrase = Get-Passphrase $Force
    
    Write-Host ""
    foreach ($File in $Files)
    {
        Encrypt-File $File $Passphrase $Force
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
