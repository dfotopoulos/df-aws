<#
.SYNOPSIS
    All-in-one EC2 Windows VM Management Tool for df-aws.

.DESCRIPTION
    Allows starting, stopping, getting details, checking status, and connecting
    to the windows-dev-test-pc EC2 instance.

.PARAMETER Action
    One of: status, start, stop, details, connect

.EXAMPLE
    .\manage-vm.ps1 status
    .\manage-vm.ps1 start
    .\manage-vm.ps1 stop
    .\manage-vm.ps1 details
    .\manage-vm.ps1 connect
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $false)]
    [ValidateSet("status", "start", "stop", "details", "connect", "list")]
    [string]$Action = "status",

    [Parameter(Mandatory = $false)]
    [string]$InstanceId = "i-0c69f686dce985f3f",

    [Parameter(Mandatory = $false)]
    [string]$Username = "Administrator"
)

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$keyPath = "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"

function Get-VMData {
    param([string]$Id)
    $raw = aws ec2 describe-instances --instance-ids $Id --output json | ConvertFrom-Json
    return $raw.Reservations[0].Instances[0]
}

switch ($Action) {
    "list" {
        Write-Host "Listing all EC2 instances..." -ForegroundColor Cyan
        aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0],State.Name,InstanceType,PublicIpAddress,PrivateIpAddress]" --output table
    }

    "status" {
        Write-Host "Fetching status for $InstanceId..." -ForegroundColor Cyan
        $vm = Get-VMData -Id $InstanceId
        $state = $vm.State.Name
        $color = switch ($state) {
            "running" { "Green" }
            "stopped" { "Red" }
            "stopping" { "Yellow" }
            "pending" { "Yellow" }
            Default { "Gray" }
        }
        Write-Host "Instance Name : $(($vm.Tags | Where-Object { $_.Key -eq 'Name' }).Value)" -ForegroundColor White
        Write-Host "Instance ID   : $($vm.InstanceId)" -ForegroundColor White
        Write-Host "State         : $state" -ForegroundColor $color
        Write-Host "Instance Type : $($vm.InstanceType)" -ForegroundColor White
        Write-Host "Public IP     : $(if ($vm.PublicIpAddress) { $vm.PublicIpAddress } else { 'None (Stopped)' })" -ForegroundColor White
        Write-Host "Public DNS    : $(if ($vm.PublicDnsName) { $vm.PublicDnsName } else { 'None (Stopped)' })" -ForegroundColor White
    }

    "start" {
        Write-Host "Starting instance $InstanceId..." -ForegroundColor Cyan
        aws ec2 start-instances --instance-ids $InstanceId --output table
        Write-Host "Waiting for instance to enter 'running' state..." -ForegroundColor Yellow
        aws ec2 wait instance-running --instance-ids $InstanceId
        $vm = Get-VMData -Id $InstanceId
        Write-Host "[+] Instance is now RUNNING!" -ForegroundColor Green
        Write-Host "    New Public IP : $($vm.PublicIpAddress)" -ForegroundColor Cyan
        Write-Host "    New Public DNS: $($vm.PublicDnsName)" -ForegroundColor Cyan
        Write-Host "`nNote: Windows takes ~2-4 minutes to initialize RDP after starting." -ForegroundColor Yellow
    }

    "stop" {
        Write-Host "Stopping instance $InstanceId..." -ForegroundColor Yellow
        aws ec2 stop-instances --instance-ids $InstanceId --output table
        Write-Host "Waiting for instance to enter 'stopped' state..." -ForegroundColor Yellow
        aws ec2 wait instance-stopped --instance-ids $InstanceId
        Write-Host "[+] Instance is now STOPPED. Compute billing has ceased." -ForegroundColor Green
    }

    "details" {
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " Full Instance Details: $InstanceId" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        aws ec2 describe-instances --instance-ids $InstanceId --output json
    }

    "connect" {
        Write-Host "Preparing RDP connection for user '$Username'..." -ForegroundColor Cyan
        $vm = Get-VMData -Id $InstanceId
        if ($vm.State.Name -ne "running") {
            Write-Host "[-] Instance is currently '$($vm.State.Name)'. Run '.\manage-vm.ps1 start' first." -ForegroundColor Red
            return
        }

        $dns = $vm.PublicDnsName
        if (-not $dns) {
            Write-Host "[-] Instance has no public DNS assigned." -ForegroundColor Red
            return
        }

        if ($Username -eq "Administrator") {
            Write-Host "Retrieving Administrator password..." -ForegroundColor Cyan
            $pwData = aws ec2 get-password-data --instance-id $InstanceId --priv-launch-key $keyPath --output json | ConvertFrom-Json

            if ($pwData.PasswordData) {
                Set-Clipboard -Value $pwData.PasswordData
                Write-Host "[+] Administrator password copied to clipboard!" -ForegroundColor Green
                Write-Host "    Target Host: $dns" -ForegroundColor White
                Write-Host "    Username   : .\Administrator" -ForegroundColor Yellow
                Write-Host "    Password   : (In clipboard, press Ctrl+V)" -ForegroundColor Yellow
            } else {
                Write-Host "[-] Could not retrieve password. Ensure instance has completed initialization." -ForegroundColor Red
                return
            }
        } else {
            Write-Host "[*] Connecting with custom local account: .\$Username" -ForegroundColor Yellow
            Write-Host "    (Ensure user '$Username' has been created inside Windows and added to Remote Desktop Users)" -ForegroundColor Gray
        }

        # Generate dynamic RDP file for the active DNS
        $rdpContent = @"
full address:s:$dns
username:s:.\$Username
prompt for credentials:i:1
administrative session:i:1
screen mode id:i:2
session bpp:i:32
compression:i:1
redirectclipboard:i:1
authentication level:i:2
enablecredsspsupport:i:1
"@
        $tempRdp = Join-Path $PSScriptRoot "..\windows-dev-test-pc.rdp"
        Set-Content -Path $tempRdp -Value $rdpContent -Encoding Ascii

        Write-Host "`nLaunching Remote Desktop..." -ForegroundColor Cyan
        Start-Process mstsc.exe -ArgumentList (Resolve-Path $tempRdp).Path
    }
}
