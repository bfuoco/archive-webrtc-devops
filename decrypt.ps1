Param()
$ErrorActionPreference = "Stop"

Import-Module -Force -DisableNameChecking -Name "$PWD\psm\aes"

Test-Aes

#$Key = $Env:ORBBA_AES256_KEY
#Test-Key $Key

Write-Host ""

$Files = Get-SecretFiles
$FilesToDecrypt = @()
foreach ($File in $Files)
{
    $IsEncrypted = Check-Encrypted $File
    if ($IsEncrypted)
    {
        $FilesToDecrypt = $FilesToDecrypt += $File
    }
}

Write-Host ""
if ($FilesToDecrypt.Length -gt 0)
{
    foreach ($File in $FilesToDecrypt)
    {
        Decrypt-File $File $Key
    }
}
else
{
    Write-Host "No files to decrypt."
}

Write-Host ""