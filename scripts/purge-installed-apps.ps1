<#
.SYNOPSIS
    In-Guest Application Purge and Cleanup Script for Windows EC2.

.DESCRIPTION
    Runs inside the Windows VM (or via AWS Systems Manager) to uninstall
    third-party software added via winget, clean program folders, and flush temp caches.

.PARAMETER KeepUser
    If set to $false, also deletes the local user 'df' and removes their profile directory.
    Default is $true (keeps the user account).
#>

[CmdletBinding()]
param (
    [bool]$KeepUser = $true
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " In-Guest Application Purge & System Cleanup" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Purge Known Third-Party Applications via Winget
$appsToPurge = @(
    "Microsoft.PowerToys",
    "Git.Git",
    "Google.Chrome",
    "Microsoft.VisualStudioCode",
    "7zip.7zip"
)

Write-Host "`n[1] Scanning and uninstalling third-party packages via winget..." -ForegroundColor Yellow
foreach ($app in $appsToPurge) {
    Write-Host "Checking for $app..." -ForegroundColor Gray
    try {
        $check = winget list --id $app 2>$null | Out-String
        if ($check -match $app) {
            Write-Host "Uninstalling $app..." -ForegroundColor Cyan
            winget uninstall --id $app --silent --accept-source-agreements 2>$null | Out-Null
            Write-Host "[+] Successfully uninstalled $app" -ForegroundColor Green
        } else {
            Write-Host "[-] $app is not installed." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "[-] Error checking/uninstalling $app: $_" -ForegroundColor Red
    }
}

# 2. Clean Up Leftover Application Directories
Write-Host "`n[2] Cleaning leftover application directories in Program Files..." -ForegroundColor Yellow
$foldersToClean = @(
    "C:\Program Files\PowerToys",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\PowerToys.lnk"
)

foreach ($path in $foldersToClean) {
    if (Test-Path $path) {
        Write-Host "Removing leftover path: $path" -ForegroundColor Cyan
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 3. Clean Temp Files and Caches
Write-Host "`n[3] Flushing temporary files and system caches..." -ForegroundColor Yellow
$tempPaths = @(
    "C:\Windows\Temp\*",
    "$env:TEMP\*"
)

foreach ($t in $tempPaths) {
    Remove-Item -Path $t -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[+] Temp directories purged." -ForegroundColor Green

# 4. Optional: Reset Local User Account
if (-not $KeepUser) {
    Write-Host "`n[4] Removing secondary local user 'df'..." -ForegroundColor Yellow
    net user df /delete 2>$null
    Write-Host "[+] User 'df' removed. Only 'Administrator' remains." -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Purge Complete! All added applications have been removed." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
