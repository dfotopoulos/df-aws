<#
.SYNOPSIS
    All-in-one EC2 Windows VM Management Tool for df-aws.

.DESCRIPTION
    Allows starting, stopping, getting details, checking status, connecting,
    resetting, taking screenshots, creating, modifying (adding users, resizing, renaming),
    and tearing down (purging) the Windows EC2 instance.

.PARAMETER Action
    One of: status, start, stop, details, connect, list, running, reset, screenshot, create, modify, add-user, teardown, purge

.EXAMPLE
    .\manage-vm.ps1 status
    .\manage-vm.ps1 start
    .\manage-vm.ps1 stop
    .\manage-vm.ps1 details
    .\manage-vm.ps1 connect
    .\manage-vm.ps1 connect -Username developer
    .\manage-vm.ps1 list
    .\manage-vm.ps1 list -Running
    .\manage-vm.ps1 running
    .\manage-vm.ps1 create -Name my-vm
    .\manage-vm.ps1 create -Name my-vm -NewUser developer
    .\manage-vm.ps1 modify -NewUser df
    .\manage-vm.ps1 modify -Name nanomegas-format-code -NewUser df
    .\manage-vm.ps1 teardown
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $false)]
    [ValidateSet("status", "start", "stop", "details", "connect", "list", "running", "reset", "screenshot", "create", "modify", "modify-vm", "add-user", "teardown", "purge", "destroy")]
    [string]$Action = "status",

    [Parameter(Mandatory = $false)]
    [string]$InstanceId = "i-078f78f26356eb712",

    [Parameter(Mandatory = $false)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [switch]$Running,

    [Parameter(Mandatory = $false)]
    [string]$InstanceType = "t3.large",

    [Parameter(Mandatory = $false)]
    [int]$VolumeSize = 120,

    [Parameter(Mandatory = $false)]
    [string]$AmiId,

    [Parameter(Mandatory = $false)]
    [string]$KeyName = "rsa-sweden-aws",

    [Parameter(Mandatory = $false)]
    [string]$SecurityGroupId = "sg-043f8722ce2abe795",

    [Parameter(Mandatory = $false)]
    [string]$SubnetId = "subnet-056112256a984f0ab",

    [Parameter(Mandatory = $false)]
    [string]$UserDataPath,

    [Parameter(Mandatory = $false)]
    [Alias("User", "AddUser")]
    [string]$NewUser,

    [Parameter(Mandatory = $false)]
    [Alias("Password")]
    [string]$NewUserPassword,

    [Parameter(Mandatory = $false)]
    [Alias("Rename")]
    [string]$NewName,

    [Parameter(Mandatory = $false)]
    [string]$Username = "Administrator",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$keyPath = "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"

function Get-VMData {
    param([string]$Id)
    try {
        $raw = aws ec2 describe-instances --instance-ids $Id --output json 2>$null | ConvertFrom-Json
        if ($raw.Reservations -and $raw.Reservations.Count -gt 0) {
            return $raw.Reservations[0].Instances[0]
        }
    } catch {
        return $null
    }
    return $null
}

# If a Name was provided for actions other than create, resolve its active Instance ID
if ($PSBoundParameters.ContainsKey('Name') -and $Action -ne "create") {
    $matched = aws ec2 describe-instances --filters "Name=tag:Name,Values=$Name" "Name=instance-state-name,Values=pending,running,stopped,stopping" --output json 2>$null | ConvertFrom-Json
    if ($matched.Reservations -and $matched.Reservations.Count -gt 0 -and $matched.Reservations[0].Instances.Count -gt 0) {
        $InstanceId = $matched.Reservations[0].Instances[0].InstanceId
    } else {
        $termCheck = aws ec2 describe-instances --filters "Name=tag:Name,Values=$Name" --output json 2>$null | ConvertFrom-Json
        if ($termCheck.Reservations -and $termCheck.Reservations.Count -gt 0 -and $termCheck.Reservations[0].Instances.Count -gt 0) {
            $tInst = $termCheck.Reservations[0].Instances[0]
            Write-Host "[-] Instance with Name '$Name' exists ($($tInst.InstanceId)), but is in state '$($tInst.State.Name)'." -ForegroundColor Yellow
        } else {
            Write-Host "[-] Error: No EC2 instance found with Name '$Name'." -ForegroundColor Red
        }
        return
    }
}

switch ($Action) {
    "screenshot" {
        Write-Host "Capturing Windows console screenshot for $InstanceId..." -ForegroundColor Cyan
        $screen = aws ec2 get-console-screenshot --instance-id $InstanceId --output json | ConvertFrom-Json
        if ($screen.ImageData) {
            $outPath = Join-Path $PSScriptRoot "screenshot.jpg"
            [System.IO.File]::WriteAllBytes($outPath, [System.Convert]::FromBase64String($screen.ImageData))
            Write-Host "[+] Screenshot saved to $outPath" -ForegroundColor Green
            Start-Process $outPath
        } else {
            Write-Host "[-] Screenshot not available yet (instance may be off or early booting)." -ForegroundColor Yellow
        }
    }
    "reset" {
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host " WARNING: CLOUD FACTORY RESET (REPLACE ROOT VOLUME)" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "This will replace the instance disk with the original clean AMI." -ForegroundColor Yellow
        Write-Host "ALL added applications (PowerToys, etc.), files, and custom users" -ForegroundColor Yellow
        Write-Host "on the C: drive will be PERMANENTLY WIPED." -ForegroundColor Yellow
        Write-Host "The Instance ID ($InstanceId) and IP address are preserved." -ForegroundColor Cyan

        if (-not $Force) {
            $confirm = Read-Host "`nType 'YES' to proceed with factory reset"
            if ($confirm -ne "YES") {
                Write-Host "[-] Reset aborted by user." -ForegroundColor Gray
                return
            }
        }

        Write-Host "`n[*] Initiating Root Volume Replacement task via AWS CLI..." -ForegroundColor Cyan
        $task = aws ec2 create-replace-root-volume-task --instance-id $InstanceId --delete-replaced-root-volume --output json | ConvertFrom-Json
        $taskId = $task.ReplaceRootVolumeTask.ReplaceRootVolumeTaskId
        Write-Host "[+] Task created: $taskId" -ForegroundColor Green
        Write-Host "Waiting for root volume replacement to complete (usually 1-2 minutes)..." -ForegroundColor Yellow

        while ($true) {
            Start-Sleep -Seconds 5
            $statusCheck = aws ec2 describe-replace-root-volume-tasks --replace-root-volume-task-ids $taskId --output json | ConvertFrom-Json
            $state = $statusCheck.ReplaceRootVolumeTasks[0].TaskState
            Write-Host "    Current task state: $state" -ForegroundColor Gray
            if ($state -eq "succeeded") {
                Write-Host "`n[+] Factory reset SUCCEEDED! All added applications are purged." -ForegroundColor Green
                Write-Host "    Windows Server 2025 is now rebooting in its initial pristine state." -ForegroundColor Cyan
                break
            } elseif ($state -in @("failed", "cancelled")) {
                Write-Host "[-] Reset task ended with state: $state" -ForegroundColor Red
                break
            }
        }
    }
    { $_ -in "list", "running" } {
        $filterArgs = @()
        if ($Action -eq "running" -or $Running) {
            Write-Host "Listing RUNNING EC2 instances..." -ForegroundColor Cyan
            $filterArgs = @("--filters", "Name=instance-state-name,Values=running")
        } else {
            Write-Host "Listing ALL EC2 instances..." -ForegroundColor Cyan
        }

        $raw = aws ec2 describe-instances @filterArgs --output json 2>$null | ConvertFrom-Json
        $list = @()
        if ($raw.Reservations) {
            foreach ($res in $raw.Reservations) {
                foreach ($inst in $res.Instances) {
                    $nameTag = ($inst.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -ExpandProperty Value)
                    $list += [PSCustomObject]@{
                        "Name"        = if ($nameTag) { $nameTag } else { "(unnamed)" }
                        "InstanceId"  = $inst.InstanceId
                        "State"       = $inst.State.Name
                        "Type"        = $inst.InstanceType
                        "PublicIP"    = if ($inst.PublicIpAddress) { $inst.PublicIpAddress } else { "-" }
                        "PrivateIP"   = if ($inst.PrivateIpAddress) { $inst.PrivateIpAddress } else { "-" }
                        "LaunchTime"  = $inst.LaunchTime
                    }
                }
            }
        }

        if ($list.Count -eq 0) {
            if ($Action -eq "running" -or $Running) {
                Write-Host "[-] No running EC2 instances found." -ForegroundColor Yellow
            } else {
                Write-Host "[-] No EC2 instances found." -ForegroundColor Yellow
            }
        } else {
            $list | Format-Table -AutoSize
            Write-Host "Total: $($list.Count) instance(s)" -ForegroundColor Gray
        }
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
        $connUser = if ($PSBoundParameters.ContainsKey('Username')) { $Username } elseif ($NewUser) { $NewUser } else { "Administrator" }
        Write-Host "Preparing RDP connection for user '$connUser'..." -ForegroundColor Cyan
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

        if ($connUser -eq "Administrator") {
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
            Write-Host "[*] Connecting with custom local account: .\$connUser" -ForegroundColor Yellow
            Write-Host "    (Ensure user '$connUser' has been created inside Windows and added to Remote Desktop Users)" -ForegroundColor Gray
        }

        # Generate dynamic RDP file for the active DNS
        $rdpContent = @"
full address:s:$dns
username:s:.\$connUser
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

    "create" {
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " Launching New Windows Instance (Windows 11 / Server 2025)" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan

        # 1. Enforce mandatory VM Name
        if ([string]::IsNullOrWhiteSpace($Name)) {
            if (-not $Force) {
                $Name = Read-Host "Enter the mandatory VM name"
            }
            if ([string]::IsNullOrWhiteSpace($Name)) {
                Write-Host "[-] The creation of the VM did not succeed because the VM name is mandatory. Please specify -Name <NAME>." -ForegroundColor Red
                return
            }
        }

        # 2. Check if an active instance with the same name tag already exists
        $existing = aws ec2 describe-instances --filters "Name=tag:Name,Values=$Name" "Name=instance-state-name,Values=pending,running,stopped,stopping" --output json 2>$null | ConvertFrom-Json
        if ($existing.Reservations -and $existing.Reservations.Count -gt 0 -and $existing.Reservations[0].Instances.Count -gt 0) {
            $existingInst = $existing.Reservations[0].Instances[0]
            $existingId = $existingInst.InstanceId
            $existingState = $existingInst.State.Name
            $color = switch ($existingState) {
                "running" { "Green" }
                "stopped" { "Red" }
                "stopping" { "Yellow" }
                "pending" { "Yellow" }
                Default { "Gray" }
            }
            Write-Host "[-] Error: The creation of the VM with name '$Name' did not succeed because it already exists." -ForegroundColor Red
            Write-Host "`nExisting VM Status:" -ForegroundColor Yellow
            Write-Host "  Name Tag      : $Name" -ForegroundColor White
            Write-Host "  Instance ID   : $existingId" -ForegroundColor White
            Write-Host "  Current State : $existingState" -ForegroundColor $color
            Write-Host "  Instance Type : $($existingInst.InstanceType)" -ForegroundColor White
            Write-Host "  Public IP     : $(if ($existingInst.PublicIpAddress) { $existingInst.PublicIpAddress } else { 'None (Stopped)' })" -ForegroundColor White
            Write-Host "  Private IP    : $($existingInst.PrivateIpAddress)" -ForegroundColor White
            Write-Host "  Launch Time   : $($existingInst.LaunchTime)" -ForegroundColor White
            return
        }

        # 3. Resolve AMI if not explicitly provided (Windows Server 2025 has the Windows 11 Desktop Experience)
        if (-not $AmiId) {
            Write-Host "[*] Querying latest Windows Server 2025 (Windows 11 codebase) AMI from AWS SSM..." -ForegroundColor Cyan
            $AmiId = aws ssm get-parameter --name "/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base" --query "Parameter.Value" --output text 2>$null
            if (-not $AmiId -or $AmiId -match "error") {
                Write-Host "[-] SSM query failed. Falling back to default AMI ami-00c776e9c84f3cb49." -ForegroundColor Yellow
                $AmiId = "ami-00c776e9c84f3cb49"
            }
        }

        Write-Host "`nConfiguration:" -ForegroundColor White
        Write-Host "  Name Tag          : $Name" -ForegroundColor Yellow
        Write-Host "  AMI ID            : $AmiId (Windows Server 2025 / Windows 11 Desktop)" -ForegroundColor Yellow
        Write-Host "  Instance Type     : $InstanceType" -ForegroundColor Yellow
        Write-Host "  Storage Size      : $VolumeSize GB (gp3, DeleteOnTermination = True)" -ForegroundColor Yellow
        Write-Host "  Key Pair          : $KeyName" -ForegroundColor Yellow
        Write-Host "  Security Group    : $SecurityGroupId" -ForegroundColor Yellow
        Write-Host "  Subnet ID         : $SubnetId" -ForegroundColor Yellow
        if ($NewUser) {
            Write-Host "  New User Account  : $NewUser (Administrators & Remote Desktop Users)" -ForegroundColor Yellow
        }
        if ($UserDataPath) {
            Write-Host "  User Data Script  : $UserDataPath" -ForegroundColor Yellow
        }

        if (-not $Force) {
            $confirm = Read-Host "`nType 'YES' to launch this new Windows EC2 instance"
            if ($confirm -ne "YES") {
                Write-Host "[-] Creation aborted by user." -ForegroundColor Gray
                return
            }
        }

        # Prepare User Data (custom user creation or provided script)
        $effectiveUserData = $UserDataPath
        $tempUserFile = $null

        if ($NewUser) {
            if (-not $NewUserPassword) {
                if (-not $Force) {
                    $NewUserPassword = Read-Host "Enter password for new Windows user '$NewUser'"
                }
                if (-not $NewUserPassword) {
                    $chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*"
                    $rand = New-Object System.Random
                    $NewUserPassword = (-join (1..16 | ForEach-Object { $chars[$rand.Next(0, $chars.Length)] }))
                }
            }

            $userScript = @"
<powershell>
net user $NewUser "$NewUserPassword" /add /y
net localgroup Administrators $NewUser /add
net localgroup "Remote Desktop Users" $NewUser /add
</powershell>
"@
            $tempUserFile = Join-Path $env:TEMP "ec2_userdata_$([Guid]::NewGuid().ToString('N')).ps1"
            Set-Content -Path $tempUserFile -Value $userScript -Encoding Utf8
            $effectiveUserData = $tempUserFile
        }

        $bdmJson = @"
[
  {
    "DeviceName": "/dev/sda1",
    "Ebs": {
      "VolumeSize": $VolumeSize,
      "VolumeType": "gp3",
      "DeleteOnTermination": true
    }
  }
]
"@

        $cliArgs = @(
            "ec2", "run-instances",
            "--image-id", $AmiId,
            "--instance-type", $InstanceType,
            "--key-name", $KeyName,
            "--security-group-ids", $SecurityGroupId,
            "--subnet-id", $SubnetId,
            "--block-device-mappings", $bdmJson,
            "--tag-specifications", "ResourceType=instance,Tags=[{Key=Name,Value=$Name}]",
            "--output", "json"
        )

        if ($effectiveUserData -and (Test-Path $effectiveUserData)) {
            $cliArgs += @("--user-data", "file://$effectiveUserData")
        }

        Write-Host "`n[*] Sending run-instances command to AWS EC2..." -ForegroundColor Cyan
        $runResult = aws @cliArgs | ConvertFrom-Json

        if (-not $runResult.Instances -or $runResult.Instances.Count -eq 0) {
            Write-Host "[-] Failed to launch instance." -ForegroundColor Red
            return
        }

        $newInstanceId = $runResult.Instances[0].InstanceId
        Write-Host "[+] Instance created with ID: $newInstanceId" -ForegroundColor Green
        Write-Host "Waiting for instance to enter 'running' state..." -ForegroundColor Yellow
        aws ec2 wait instance-running --instance-ids $newInstanceId

        $vm = Get-VMData -Id $newInstanceId
        Write-Host "`n[+] Instance entered 'running' state!" -ForegroundColor Green
        Write-Host "    Instance ID   : $($vm.InstanceId)" -ForegroundColor Cyan
        Write-Host "    Public IP     : $($vm.PublicIpAddress)" -ForegroundColor Cyan
        Write-Host "    Public DNS    : $($vm.PublicDnsName)" -ForegroundColor Cyan

        # Update default $InstanceId in this script file
        $scriptPath = $PSCommandPath
        if ($scriptPath -and (Test-Path $scriptPath)) {
            $content = Get-Content -Path $scriptPath -Raw
            $updatedContent = $content -replace '\[string\]\$InstanceId\s*=\s*"[^"]+"', "[string]`$InstanceId = `"$newInstanceId`""
            if ($updatedContent -ne $content) {
                Set-Content -Path $scriptPath -Value $updatedContent -Encoding Utf8
                Write-Host "[+] Updated default InstanceId in $(Split-Path $scriptPath -Leaf) to $newInstanceId" -ForegroundColor Green
            }
        }

        # Update windows-dev-test-pc.rdp if public DNS is present
        $targetRdpUser = if ($NewUser) { $NewUser } else { "Administrator" }
        if ($vm.PublicDnsName) {
            $tempRdp = Join-Path $PSScriptRoot "..\windows-dev-test-pc.rdp"
            $rdpContent = @"
full address:s:$($vm.PublicDnsName)
username:s:.\$targetRdpUser
prompt for credentials:i:1
administrative session:i:1
screen mode id:i:2
session bpp:i:32
compression:i:1
redirectclipboard:i:1
authentication level:i:2
enablecredsspsupport:i:1
"@
            Set-Content -Path $tempRdp -Value $rdpContent -Encoding Ascii
            Write-Host "[+] Updated RDP connection shortcut ($targetRdpUser): $tempRdp" -ForegroundColor Green
        }

        # Wait for Windows OS to boot and RDP service to become available
        Write-Host "`nWaiting for Windows to finish booting and become available (RDP port 3389)..." -ForegroundColor Yellow
        $maxRetries = 60
        $isAvailable = $false
        for ($i = 0; $i -lt $maxRetries; $i++) {
            Start-Sleep -Seconds 5
            Write-Host "." -NoNewline
            if ($vm.PublicIpAddress) {
                $test = Test-NetConnection -ComputerName $vm.PublicIpAddress -Port 3389 -WarningAction SilentlyContinue -InformationLevel Quiet
                if ($test) {
                    $isAvailable = $true
                    break
                }
            }
        }
        Write-Host ""

        if ($isAvailable) {
            Write-Host "[+] Windows VM is fully booted and AVAILABLE for RDP connections!" -ForegroundColor Green
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
        } else {
            Write-Host "[!] Note: Port 3389 polling timed out, but instance is running." -ForegroundColor Yellow
        }

        # Attempt to retrieve Administrator password if available
        Write-Host "`n[*] Retrieving Administrator password..." -ForegroundColor Cyan
        $pwData = aws ec2 get-password-data --instance-id $newInstanceId --priv-launch-key $keyPath --output json 2>$null | ConvertFrom-Json
        if ($pwData -and $pwData.PasswordData) {
            Set-Clipboard -Value $pwData.PasswordData
            Write-Host "[+] Administrator password retrieved and copied to clipboard!" -ForegroundColor Green
            Write-Host "    Target Host: $($vm.PublicDnsName)" -ForegroundColor White
            Write-Host "    Username   : .\Administrator" -ForegroundColor Yellow
            Write-Host "    Password   : (In clipboard, press Ctrl+V in RDP)" -ForegroundColor Yellow
        } else {
            Write-Host "[*] Password generation still in progress (AWS typically takes 3-5 minutes post-launch)." -ForegroundColor Gray
            Write-Host "    Retrieve password and connect anytime with:" -ForegroundColor White
            Write-Host "      .\scripts\manage-vm.ps1 connect -InstanceId $newInstanceId" -ForegroundColor Cyan
        }

        if ($NewUser) {
            Write-Host "`n[+] Custom Windows user '$NewUser' provisioned via EC2 User Data!" -ForegroundColor Green
            Write-Host "    Username : .\$NewUser" -ForegroundColor Yellow
            Write-Host "    Password : $NewUserPassword" -ForegroundColor Yellow
            Write-Host "    Connect directly with:" -ForegroundColor White
            Write-Host "      .\scripts\manage-vm.ps1 connect -Username $NewUser" -ForegroundColor Cyan
        }

        if ($tempUserFile -and (Test-Path $tempUserFile)) {
            Remove-Item -Path $tempUserFile -Force -ErrorAction SilentlyContinue
        }
    }

    { $_ -in @("teardown", "purge", "destroy") } {
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host " WARNING: PERMANENT INSTANCE TEARDOWN (TERMINATION)" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "This will PERMANENTLY TERMINATE and PURGE the instance: $InstanceId" -ForegroundColor Yellow
        Write-Host "ALL data on the root volume and attached EBS storage will be permanently deleted." -ForegroundColor Yellow
        Write-Host "Compute and storage billing for this instance will cease completely." -ForegroundColor Green

        if (-not $Force) {
            $confirm = Read-Host "`nType 'YES' to permanently purge and delete this instance"
            if ($confirm -ne "YES") {
                Write-Host "[-] Teardown aborted by user." -ForegroundColor Gray
                return
            }
        }

        Write-Host "`n[*] Terminating instance $InstanceId via AWS CLI..." -ForegroundColor Cyan
        aws ec2 terminate-instances --instance-ids $InstanceId --output table

        Write-Host "Waiting for instance to enter 'terminated' state..." -ForegroundColor Yellow
        aws ec2 wait instance-terminated --instance-ids $InstanceId
        Write-Host "`n[+] Instance $InstanceId has been PERMANENTLY TERMINATED and PURGED." -ForegroundColor Green
        Write-Host "    All attached root storage has been deleted. Ongoing costs are now `$0.00." -ForegroundColor Cyan
    }

    { $_ -in @("modify", "modify-vm", "add-user") } {
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " Modify VM: $InstanceId" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan

        $vm = Get-VMData -Id $InstanceId
        if (-not $vm) {
            Write-Host "[-] Instance $InstanceId not found." -ForegroundColor Red
            return
        }

        $vmName = ($vm.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -ExpandProperty Value)
        if (-not $vmName) { $vmName = "(Unnamed)" }
        Write-Host "Target Instance : $InstanceId ($vmName)" -ForegroundColor White
        Write-Host "Current State   : $($vm.State.Name)" -ForegroundColor Yellow

        # 1. Modify / Rename VM Name tag if -NewName is provided
        if ($NewName) {
            Write-Host "`n[*] Updating instance Name tag to '$NewName'..." -ForegroundColor Cyan
            aws ec2 create-tags --resources $InstanceId --tags "Key=Name,Value=$NewName"
            Write-Host "[+] Instance Name tag updated to: $NewName" -ForegroundColor Green
        }

        # 2. Modify Instance Type if -InstanceType was explicitly passed
        if ($PSBoundParameters.ContainsKey('InstanceType')) {
            Write-Host "`n[*] Modifying Instance Type to '$InstanceType'..." -ForegroundColor Cyan
            if ($vm.State.Name -ne "stopped") {
                Write-Host "[-] Instance must be 'stopped' to change instance type (currently '$($vm.State.Name)')." -ForegroundColor Red
                Write-Host "    Run '.\manage-vm.ps1 stop' first, modify the type, then restart." -ForegroundColor Yellow
            } else {
                aws ec2 modify-instance-attribute --instance-id $InstanceId --instance-type "Value=$InstanceType"
                Write-Host "[+] Instance type modified to: $InstanceType" -ForegroundColor Green
            }
        }

        # 3. Expand EBS volume if -VolumeSize was explicitly passed
        if ($PSBoundParameters.ContainsKey('VolumeSize')) {
            $rootVolId = $vm.BlockDeviceMappings[0].Ebs.VolumeId
            if ($rootVolId) {
                Write-Host "`n[*] Modifying root EBS volume $rootVolId to ${VolumeSize} GB..." -ForegroundColor Cyan
                aws ec2 modify-volume --volume-id $rootVolId --size $VolumeSize --output table
                Write-Host "[+] Volume resize requested for $rootVolId (${VolumeSize} GB)." -ForegroundColor Green
            }
        }

        # 4. User account creation / modification on running Windows VM
        $targetUser = $NewUser
        if (-not $targetUser -and $PSBoundParameters.ContainsKey('Username') -and $Username -ne "Administrator") {
            $targetUser = $Username
        }

        if (-not $targetUser -and -not $NewName -and -not $PSBoundParameters.ContainsKey('InstanceType') -and -not $PSBoundParameters.ContainsKey('VolumeSize')) {
            if (-not $Force) {
                $targetUser = Read-Host "`nEnter Windows username to create/modify on $InstanceId (e.g. df)"
            }
            if ([string]::IsNullOrWhiteSpace($targetUser)) {
                Write-Host "[-] A username is required (e.g. .\scripts\manage-vm.ps1 modify -NewUser df)." -ForegroundColor Red
                return
            }
        }

        if ($targetUser) {
            Write-Host "`n[*] Configuring Windows local user '$targetUser' on $InstanceId..." -ForegroundColor Cyan

            if ($vm.State.Name -ne "running") {
                Write-Host "[-] Instance is currently '$($vm.State.Name)'. The VM must be 'running' to create/modify local OS users." -ForegroundColor Red
                Write-Host "    Start the instance first with: .\scripts\manage-vm.ps1 start -InstanceId $InstanceId" -ForegroundColor Yellow
                return
            }

            if (-not $NewUserPassword) {
                if (-not $Force) {
                    $NewUserPassword = Read-Host "Enter password for '$targetUser' (press Enter to auto-generate a secure random password)"
                }
                if (-not $NewUserPassword) {
                    $chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*"
                    $rand = New-Object System.Random
                    $NewUserPassword = (-join (1..16 | ForEach-Object { $chars[$rand.Next(0, $chars.Length)] }))
                }
            }

            # Check AWS SSM Status
            Write-Host "[*] Checking AWS Systems Manager (SSM) agent on $InstanceId..." -ForegroundColor Cyan
            $ssmInfo = aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$InstanceId" --output json 2>$null | ConvertFrom-Json
            if (-not $ssmInfo.InstanceInformationList -or $ssmInfo.InstanceInformationList.Count -eq 0 -or $ssmInfo.InstanceInformationList[0].PingStatus -ne "Online") {
                Write-Host "[-] Instance $InstanceId is not currently online in AWS Systems Manager." -ForegroundColor Yellow
                Write-Host "    SSM agent may be starting up or the instance lacks an SSM IAM role." -ForegroundColor Gray
                Write-Host "    You can still connect via RDP as Administrator and run in PowerShell:" -ForegroundColor White
                Write-Host "      net user $targetUser `"$NewUserPassword`" /add /y" -ForegroundColor Gray
                Write-Host "      net localgroup Administrators $targetUser /add" -ForegroundColor Gray
                Write-Host "      net localgroup `"Remote Desktop Users`" $targetUser /add" -ForegroundColor Gray
                return
            }

            $uB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($targetUser))
            $pB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($NewUserPassword))

            $guestScript = @(
                "`$u = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$uB64'))",
                "`$p = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$pB64'))",
                "`$sec = ConvertTo-SecureString `$p -AsPlainText -Force",
                "`$existing = Get-LocalUser -Name `$u -ErrorAction SilentlyContinue",
                "if (`$existing) {",
                "    `$existing | Set-LocalUser -Password `$sec",
                "    Write-Output 'STATUS:UPDATED'",
                "} else {",
                "    New-LocalUser -Name `$u -Password `$sec -FullName `$u -Description 'Created via manage-vm.ps1' | Out-Null",
                "    Write-Output 'STATUS:CREATED'",
                "}",
                "Set-LocalUser -Name `$u -PasswordNeverExpires `$true -ErrorAction SilentlyContinue",
                "Add-LocalGroupMember -Group 'Administrators' -Member `$u -ErrorAction SilentlyContinue",
                "Add-LocalGroupMember -Group 'Remote Desktop Users' -Member `$u -ErrorAction SilentlyContinue",
                "`$admin = [bool](Get-LocalGroupMember -Group 'Administrators' | Where-Object { `$_.Name -like `"*`$u`" })",
                "`$rdp = [bool](Get-LocalGroupMember -Group 'Remote Desktop Users' | Where-Object { `$_.Name -like `"*`$u`" })",
                "Write-Output `"ADMIN:`$admin`"",
                "Write-Output `"RDP:`$rdp`""
            )

            $req = @{
                InstanceIds = @($InstanceId)
                DocumentName = 'AWS-RunPowerShellScript'
                Parameters = @{
                    commands = $guestScript
                }
            }

            $tmpReq = Join-Path $env:TEMP "ssm_user_$([Guid]::NewGuid().ToString('N')).json"
            $req | ConvertTo-Json -Depth 5 | Set-Content -Path $tmpReq -Encoding Ascii

            Write-Host "[*] Sending user configuration command via AWS SSM..." -ForegroundColor Cyan
            $cmdResult = aws ssm send-command --cli-input-json "file://$tmpReq" --output json 2>$null | ConvertFrom-Json
            Remove-Item $tmpReq -Force -ErrorAction SilentlyContinue

            if (-not $cmdResult.Command.CommandId) {
                Write-Host "[-] Failed to dispatch SSM command to instance $InstanceId." -ForegroundColor Red
                return
            }

            $cmdId = $cmdResult.Command.CommandId
            Write-Host "Waiting for guest execution (Command ID: $cmdId)..." -ForegroundColor Yellow

            $inv = $null
            for ($i = 0; $i -lt 30; $i++) {
                Start-Sleep -Seconds 1
                Write-Host "." -NoNewline
                $inv = aws ssm get-command-invocation --command-id $cmdId --instance-id $InstanceId --output json 2>$null | ConvertFrom-Json
                if ($inv -and $inv.Status -in @('Success', 'Failed', 'TimedOut', 'Cancelled')) {
                    break
                }
            }
            Write-Host ""

            if ($inv -and $inv.Status -eq "Success") {
                $outText = $inv.StandardOutputContent
                $isCreated = $outText -match "STATUS:CREATED"
                $statusLabel = if ($isCreated) { "created" } else { "updated (password & privileges updated)" }

                Set-Clipboard -Value $NewUserPassword

                Write-Host "`n[+] User '$targetUser' successfully $statusLabel on instance $InstanceId!" -ForegroundColor Green
                Write-Host "    Instance Name : $vmName" -ForegroundColor White
                Write-Host "    Target Host   : $($vm.PublicDnsName)" -ForegroundColor White
                Write-Host "    Username      : .\$targetUser" -ForegroundColor Yellow
                Write-Host "    Password      : $NewUserPassword (Copied to clipboard)" -ForegroundColor Yellow
                Write-Host "    Privileges    : Administrators & Remote Desktop Users" -ForegroundColor Green

                # Update windows-dev-test-pc.rdp
                if ($vm.PublicDnsName) {
                    $tempRdp = Join-Path $PSScriptRoot "..\windows-dev-test-pc.rdp"
                    $rdpContent = @"
full address:s:$($vm.PublicDnsName)
username:s:.\$targetUser
prompt for credentials:i:1
administrative session:i:1
screen mode id:i:2
session bpp:i:32
compression:i:1
redirectclipboard:i:1
authentication level:i:2
enablecredsspsupport:i:1
"@
                    Set-Content -Path $tempRdp -Value $rdpContent -Encoding Ascii
                    Write-Host "[+] Updated RDP connection shortcut ($targetUser): $tempRdp" -ForegroundColor Green
                }

                Write-Host "`nConnect directly with:" -ForegroundColor White
                Write-Host "  .\scripts\manage-vm.ps1 connect -Username $targetUser" -ForegroundColor Cyan
            } else {
                Write-Host "[-] Command execution failed with status: $($inv.Status)" -ForegroundColor Red
                if ($inv.StandardErrorContent) {
                    Write-Host "    Error: $($inv.StandardErrorContent)" -ForegroundColor Red
                }
            }
        }
    }
}

