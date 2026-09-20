<#
.SYNOPSIS
    Connects to the EC2 Windows instance via Remote Desktop Connection.

.DESCRIPTION
    Decrypts the Windows Administrator password using the AWS CLI and local PEM key,
    copies the password to the Windows clipboard, and launches mstsc.
#>

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

$instanceId = "i-0c69f686dce985f3f"
$keyPath = "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"
$rdpFile = Join-Path $PSScriptRoot "..\windows-dev-test-pc.rdp"

Write-Host "Retrieving Windows Administrator password via AWS CLI..." -ForegroundColor Cyan
$pwData = aws ec2 get-password-data --instance-id $instanceId --priv-launch-key $keyPath --output json | ConvertFrom-Json

if ($pwData.PasswordData) {
    Set-Clipboard -Value $pwData.PasswordData
    Write-Host "[+] Password successfully retrieved and copied to your clipboard!" -ForegroundColor Green
    Write-Host "    Username: .\Administrator" -ForegroundColor Yellow
    Write-Host "    Password: (Copied to clipboard - just press Ctrl+V)" -ForegroundColor Yellow
    Write-Host "`nLaunching Remote Desktop..." -ForegroundColor Cyan
    Start-Process mstsc.exe -ArgumentList (Resolve-Path $rdpFile).Path
} else {
    Write-Host "[-] Failed to retrieve password data." -ForegroundColor Red
}
