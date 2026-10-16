<#
.SYNOPSIS
    All-in-one AWS EC2 Windows VM Lifecycle & Management CLI for df-aws.

.DESCRIPTION
    Provides complete lifecycle management for AWS EC2 Windows instances (Windows Server 2025 /
    Windows 11 Desktop Experience) via the AWS CLI and AWS Systems Manager (SSM).

    Capabilities include:
      - Discovery & Inspection : Check status, list all or running VMs, dump full JSON metadata,
                                 and capture live console screenshots.
      - Power & RDP Connection : Start and stop instances (with compute-billing safeguards),
                                 decrypt the Administrator password via PEM key to the clipboard,
                                 dynamically generate/update the RDP file, and launch mstsc.exe.
      - Provisioning (create)  : Launch a new Windows Server 2025 VM with duplicate-name protection,
                                 optional custom Admin/RDP user bootstrap via EC2 User Data, automatic
                                 port 3389 readiness polling, and auto-updating of script defaults.
      - In-Place Modification  : Add or update local Windows OS users (Administrators + Remote Desktop
                                 Users) live via AWS SSM without rebooting, rename the VM's Name tag,
                                 change the EC2 InstanceType, or expand the root gp3 EBS volume.
      - Reset & Teardown       : Perform a cloud factory reset (root volume replacement preserving
                                 Instance ID and IP) or permanently terminate and purge the VM.
      - Rich Built-In Help     : Run `.\scripts\manage-vm.ps1 help` (or `-Help`) to view a complete
                                 colorized command reference with `windows-dev-test-pc` examples and
                                 underlying `aws` CLI equivalents.

.PARAMETER Action
    The management command to execute. Defaults to "status".
    Allowed values:
      - help, usage                : Display the rich command reference and examples.
      - status                     : Show a concise health & network summary for the target VM.
      - list                       : List all EC2 instances in the region (or only running with -Running).
      - running                    : Shortcut to list only currently running EC2 instances.
      - start                      : Start a stopped VM and wait until it reaches 'running' state.
      - stop                       : Stop a running VM (requires -Name) so compute billing ceases.
      - connect                    : Decrypt password (if Administrator), update .rdp file, and launch mstsc.exe.
      - details                    : Output complete raw AWS EC2 describe-instances JSON metadata.
      - screenshot                 : Capture and open a live JPG screenshot of the Windows console display.
      - create                     : Launch a new Windows Server 2025 EC2 instance (requires -Name).
      - modify, modify-vm, add-user: Modify an existing VM (add/update OS user via SSM, rename, resize CPU/RAM/disk).
      - reset                      : Cloud factory reset — replace root EBS volume with clean base AMI.
      - teardown, purge, destroy   : Permanently terminate the instance and delete its root EBS volume (requires -Name).

.PARAMETER InstanceId
    Target AWS EC2 Instance ID (e.g., "i-0135755d4c646aae6"). Automatically updated when `create` succeeds,
    or dynamically resolved when `-Name` is specified.

.PARAMETER Name
    The human-readable EC2 `Name` tag of the VM (e.g., "windows-dev-test-pc").
    - Mandatory for `create`, `stop`, `teardown`, `purge`, and `destroy` (prompts interactively if omitted without -Force).
    - Optional for all other commands; when provided, resolves the active Instance ID by `tag:Name`.

.PARAMETER Running
    Switch used with the `list` action (`.\scripts\manage-vm.ps1 list -Running`) to filter only running instances.

.PARAMETER InstanceType
    EC2 compute instance type (default: "t3.large" — 2 vCPUs, 8 GiB RAM).
    Used when launching a new VM (`create`) or resizing a stopped VM (`modify -InstanceType <type>`).

.PARAMETER VolumeSize
    Root EBS gp3 volume size in GB (default: 120).
    Used when launching a new VM (`create`) or expanding storage on an existing VM (`modify -VolumeSize <GB>`).

.PARAMETER AmiId
    Optional Amazon Machine Image (AMI) ID for `create`. If omitted, automatically queries AWS SSM Parameter
    Store for the latest Windows Server 2025 English Full Base AMI (`/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base`).

.PARAMETER KeyName
    AWS EC2 Key Pair name used to encrypt the Windows Administrator password at launch (default: "rsa-sweden-aws").

.PARAMETER SecurityGroupId
    Security Group ID permitting inbound TCP port 3389 for RDP (default: "sg-043f8722ce2abe795").

.PARAMETER SubnetId
    Target VPC Public Subnet ID with Internet Gateway route (default: "subnet-056112256a984f0ab").

.PARAMETER UserDataPath
    Optional path to a custom EC2 User Data script to execute during initial instance provisioning (`create`).

.PARAMETER NewUser
    Aliases: -User, -AddUser
    Local Windows username (e.g., "df" or "developer") to provision and add to local `Administrators` and
    `Remote Desktop Users` groups during `create` (via EC2 User Data) or `modify` / `add-user` (via AWS SSM).

.PARAMETER NewUserPassword
    Aliases: -Password
    Password for `-NewUser`. If omitted, prompts interactively (or auto-generates a 16-character secure
    random password when `-Force` is specified or Enter is pressed).

.PARAMETER NewName
    Aliases: -Rename
    New EC2 `Name` tag value when renaming an instance via `modify -Name <OldName> -NewName <NewName>`.

.PARAMETER Username
    Windows OS username to use when launching Remote Desktop with `connect` (default: "Administrator").
    When set to "Administrator", the script decrypts the EC2 password via the PEM key and copies it to the clipboard.

.PARAMETER Force
    Bypasses interactive confirmation prompts (`YES` prompts on `create`, `reset`, `teardown`) and generates
    random passwords automatically if `-NewUserPassword` is not supplied.

.PARAMETER Help
    Aliases: -h, -?
    Displays the rich colorized command reference with `windows-dev-test-pc` examples and exits.

.EXAMPLE
    .\scripts\manage-vm.ps1 help
    Displays the rich interactive help guide with all commands, parameters, and `windows-dev-test-pc` examples.

.EXAMPLE
    .\scripts\manage-vm.ps1 status -Name windows-dev-test-pc
    Checks the current state, instance type, Public IP, and Public DNS of `windows-dev-test-pc`.

.EXAMPLE
    .\scripts\manage-vm.ps1 list
    .\scripts\manage-vm.ps1 list -Running
    .\scripts\manage-vm.ps1 running
    Lists all EC2 instances in the region, or filters for currently running instances only.

.EXAMPLE
    .\scripts\manage-vm.ps1 create -Name windows-dev-test-pc
    .\scripts\manage-vm.ps1 create -Name windows-dev-test-pc -NewUser df -InstanceType t3.xlarge -VolumeSize 150 -Force
    Creates a new Windows Server 2025 VM named `windows-dev-test-pc`, optionally bootstrapping local admin user `df`.

.EXAMPLE
    .\scripts\manage-vm.ps1 start -Name windows-dev-test-pc
    z.\scripts\manage-vm.ps1 stop -Name windows-dev-test-pc
    Starts or stops the `windows-dev-test-pc` instance and waits for state transition completion.

.EXAMPLE
    .\scripts\manage-vm.ps1 connect -Name windows-dev-test-pc
    .\scripts\manage-vm.ps1 connect -Name windows-dev-test-pc -Username df
    Connects via Remote Desktop (`mstsc.exe`) as `Administrator` (password auto-copied to clipboard) or custom user `df`.

.EXAMPLE
    .\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewUser df
    .\scripts\manage-vm.ps1 add-user -Name windows-dev-test-pc -NewUser df -Password "MyStrongPassword!123"
    .\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewName windows-dev-prod-pc
    .\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -InstanceType t3.xlarge -VolumeSize 200
    Modifies `windows-dev-test-pc` in-place: creates/updates OS user `df` via AWS SSM, renames the VM, or resizes compute/storage.

.EXAMPLE
    .\scripts\manage-vm.ps1 details -Name windows-dev-test-pc
    .\scripts\manage-vm.ps1 screenshot -Name windows-dev-test-pc
    Fetches full JSON metadata or captures and opens a live console screenshot of `windows-dev-test-pc`.

.EXAMPLE
    .\scripts\manage-vm.ps1 reset -Name windows-dev-test-pc
    .\scripts\manage-vm.ps1 teardown -Name windows-dev-test-pc
    Replaces the root volume with a clean factory AMI (`reset`) or permanently terminates and purges the VM (`teardown`).

.NOTES
    Prerequisites:
      1. AWS CLI v2 installed and configured (`aws configure`).
      2. Private RSA key file at `C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem` for Administrator password decryption.
      3. IAM permissions for EC2 (`AmazonEC2FullAccess`) and SSM (`AmazonSSMFullAccess` for in-guest user management).
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $false)]
    [ValidateSet("status", "start", "stop", "details", "connect", "list", "running", "reset", "screenshot", "create", "modify", "modify-vm", "add-user", "teardown", "purge", "destroy", "help", "usage")]
    [string]$Action = "status",

    [Parameter(Mandatory = $false)]
    [string]$InstanceId = "i-0135755d4c646aae6",

    [Parameter(Position = 1, Mandatory = $false)]
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
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [Alias("h", "?")]
    [switch]$Help
)

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$keyPath = "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"

function Show-VMHelp {
    param([string]$ExampleName = "windows-dev-test-pc")

    $exVm = if ([string]::IsNullOrWhiteSpace($ExampleName)) { "windows-dev-test-pc" } else { $ExampleName }

    Write-Host ""
    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host "  AWS EC2 WINDOWS VM MANAGEMENT CLI (manage-vm.ps1) - COMPLETE COMMAND REFERENCE" -ForegroundColor Cyan
    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host "  All-in-one tool to provision, inspect, start, stop, connect (RDP), modify (users/size/tags)," -ForegroundColor White
    Write-Host "  factory-reset, and tear down Windows Server 2025 / Windows 11 EC2 instances." -ForegroundColor White
    Write-Host ""
    Write-Host "SYNOPSIS / SYNTAX:" -ForegroundColor Yellow
    Write-Host "  .\scripts\manage-vm.ps1 <Action> [-Name <VM_NAME>] [-InstanceId <ID>] [Options...]" -ForegroundColor Green
    Write-Host "  .\scripts\manage-vm.ps1 help" -ForegroundColor Green
    Write-Host "  Get-Help .\scripts\manage-vm.ps1 -Full" -ForegroundColor Gray
    Write-Host ""
    Write-Host "ACTIVE DEFAULTS:" -ForegroundColor Yellow
    Write-Host "  Example VM Name   : $exVm" -ForegroundColor White
    Write-Host "  Default InstanceId: $InstanceId" -ForegroundColor White
    Write-Host "  Default Spec      : $InstanceType | ${VolumeSize} GB gp3 EBS | Key: $KeyName" -ForegroundColor White
    Write-Host "  Network Defaults  : Subnet $SubnetId | SecurityGroup $SecurityGroupId" -ForegroundColor White
    Write-Host "  Private Key (.pem): $keyPath" -ForegroundColor White
    Write-Host ""

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " 1. DISCOVERY, STATUS & DIAGNOSTICS" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan

    Write-Host "  help (aliases: usage, -Help, -h)" -ForegroundColor Green
    Write-Host "    Display this rich command reference with '$exVm' examples and AWS CLI equivalents." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 help" -ForegroundColor White
    Write-Host ""

    Write-Host "  status (default action)" -ForegroundColor Green
    Write-Host "    Show instance Name tag, Instance ID, power state, type, Public IP, and Public DNS." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 status -Name $exVm" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 status $exVm" -ForegroundColor White
    Write-Host "    AWS> aws ec2 describe-instances --filters `"Name=tag:Name,Values=$exVm`" --output table" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  list / running" -ForegroundColor Green
    Write-Host "    List all EC2 instances in the region, or filter for currently running instances only." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 list" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 list -Running" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 running" -ForegroundColor White
    Write-Host "    AWS> aws ec2 describe-instances --filters `"Name=instance-state-name,Values=running`" --output table" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  details" -ForegroundColor Green
    Write-Host "    Output the complete raw JSON metadata tracked by AWS EC2 (VPC, EBS, SG, ENI, tags)." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 details -Name $exVm" -ForegroundColor White
    Write-Host "    AWS> aws ec2 describe-instances --instance-ids $InstanceId --output json" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  screenshot" -ForegroundColor Green
    Write-Host "    Capture a live JPG image of the Windows console screen, save to scripts\screenshot.jpg, and open it." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 screenshot -Name $exVm" -ForegroundColor White
    Write-Host "    AWS> aws ec2 get-console-screenshot --instance-id $InstanceId --output json" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " 2. POWER LIFECYCLE & REMOTE DESKTOP (RDP)" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan

    Write-Host "  start" -ForegroundColor Green
    Write-Host "    Start a stopped VM, wait until it enters 'running' state, and display its new Public IP/DNS." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 start -Name $exVm" -ForegroundColor White
    Write-Host "    AWS> aws ec2 start-instances --instance-ids $InstanceId && aws ec2 wait instance-running --instance-ids $InstanceId" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  stop  [Mandatory: -Name <VM_NAME>]" -ForegroundColor Green
    Write-Host "    Gracefully stop a running VM and wait for 'stopped' state. Halts EC2 compute billing (`$0.00/hr)." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 stop -Name $exVm" -ForegroundColor White
    Write-Host "    AWS> aws ec2 stop-instances --instance-ids $InstanceId && aws ec2 wait instance-stopped --instance-ids $InstanceId" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  connect" -ForegroundColor Green
    Write-Host "    Decrypt Administrator password via PEM key & copy to clipboard (or use custom -Username)," -ForegroundColor Gray
    Write-Host "    refresh windows-dev-test-pc.rdp with current Public DNS, and launch Remote Desktop (mstsc.exe)." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 connect -Name $exVm" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 connect -Name $exVm -Username df" -ForegroundColor White
    Write-Host "    AWS> aws ec2 get-password-data --instance-id $InstanceId --priv-launch-key `"$keyPath`"" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " 3. PROVISIONING & IN-PLACE MODIFICATION" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan

    Write-Host "  create  [Mandatory: -Name <VM_NAME>]" -ForegroundColor Green
    Write-Host "    Launch a new Windows Server 2025 (Windows 11 Desktop) VM. Checks for duplicate Name tags," -ForegroundColor Gray
    Write-Host "    queries AWS SSM for latest AMI, optionally provisions a local Admin/RDP user via User Data," -ForegroundColor Gray
    Write-Host "    polls TCP port 3389 until RDP is ready, and updates default InstanceId & .rdp shortcut." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 create -Name $exVm" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 create -Name $exVm -NewUser df" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 create -Name $exVm -NewUser df -Password `"StrongPass!123`" -InstanceType t3.xlarge -VolumeSize 150 -Force" -ForegroundColor White
    Write-Host "    AWS> aws ec2 run-instances --image-id <AmiId> --instance-type t3.large --key-name $KeyName --security-group-ids $SecurityGroupId --subnet-id $SubnetId --tag-specifications `"ResourceType=instance,Tags=[{Key=Name,Value=$exVm}]`"" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  modify (aliases: modify-vm, add-user)" -ForegroundColor Green
    Write-Host "    Modify an existing VM in-place (supports combining multiple flags in a single call):" -ForegroundColor Gray
    Write-Host "      a) Create/update local Windows Admin & RDP user live via AWS SSM (-NewUser / -User, -Password)" -ForegroundColor Gray
    Write-Host "      b) Rename the VM's Name tag (-NewName / -Rename)" -ForegroundColor Gray
    Write-Host "      c) Change EC2 InstanceType (-InstanceType; VM must be stopped)" -ForegroundColor Gray
    Write-Host "      d) Expand root gp3 EBS volume (-VolumeSize <GB>)" -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 modify -Name $exVm -NewUser df" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 add-user -Name $exVm -NewUser df -Password `"StrongPass!123`" -Force" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 modify -Name $exVm -NewName ${exVm}-v2" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 modify -Name $exVm -InstanceType t3.xlarge -VolumeSize 200" -ForegroundColor White
    Write-Host "    AWS> aws ssm send-command --instance-ids $InstanceId --document-name `"AWS-RunPowerShellScript`" ..." -ForegroundColor DarkGray
    Write-Host "    AWS> aws ec2 create-tags --resources $InstanceId --tags `"Key=Name,Value=${exVm}-v2`"" -ForegroundColor DarkGray
    Write-Host "    AWS> aws ec2 modify-instance-attribute --instance-id $InstanceId --instance-type `"Value=t3.xlarge`"" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " 4. FACTORY RESET & PERMANENT TEARDOWN" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan

    Write-Host "  reset" -ForegroundColor Green
    Write-Host "    Cloud Factory Reset: replaces the root C: EBS volume with a fresh disk from the original AMI." -ForegroundColor Gray
    Write-Host "    Wipes all installed apps, files, and custom OS users while preserving Instance ID and IP." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 reset -Name $exVm" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 reset -Name $exVm -Force" -ForegroundColor White
    Write-Host "    AWS> aws ec2 create-replace-root-volume-task --instance-id $InstanceId --delete-replaced-root-volume" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  teardown (aliases: purge, destroy)  [Mandatory: -Name <VM_NAME>]" -ForegroundColor Green
    Write-Host "    Permanently terminate the EC2 instance and delete its attached root EBS storage volume." -ForegroundColor Gray
    Write-Host "    Irreversible! All compute and disk storage billing drops to `$0.00." -ForegroundColor Gray
    Write-Host "    PS> .\scripts\manage-vm.ps1 teardown -Name $exVm" -ForegroundColor White
    Write-Host "    PS> .\scripts\manage-vm.ps1 purge -Name $exVm -Force" -ForegroundColor White
    Write-Host "    AWS> aws ec2 terminate-instances --instance-ids $InstanceId && aws ec2 wait instance-terminated --instance-ids $InstanceId" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " 5. PARAMETERS & OPTIONS SUMMARY" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  -Action <String>          : Command to run (default: status)" -ForegroundColor White
    Write-Host "  -Name <String>            : Target VM Name tag (e.g. $exVm). Mandatory for create/stop/teardown" -ForegroundColor White
    Write-Host "  -InstanceId <String>      : Target EC2 Instance ID (default: $InstanceId)" -ForegroundColor White
    Write-Host "  -Running                  : Switch for 'list' to show only running instances" -ForegroundColor White
    Write-Host "  -Username <String>        : RDP login user for 'connect' (default: Administrator)" -ForegroundColor White
    Write-Host "  -NewUser <String>         : Alias: -User, -AddUser. Local Windows user to create/update" -ForegroundColor White
    Write-Host "  -NewUserPassword <String> : Alias: -Password. Password for -NewUser (auto-generated if omitted with -Force)" -ForegroundColor White
    Write-Host "  -NewName <String>         : Alias: -Rename. New Name tag for 'modify'" -ForegroundColor White
    Write-Host "  -InstanceType <String>    : EC2 instance size for 'create' or 'modify' (default: $InstanceType)" -ForegroundColor White
    Write-Host "  -VolumeSize <Int>         : Root gp3 disk size in GB for 'create' or 'modify' (default: $VolumeSize)" -ForegroundColor White
    Write-Host "  -AmiId <String>           : Custom AMI ID for 'create' (default: latest Windows Server 2025 via SSM)" -ForegroundColor White
    Write-Host "  -KeyName <String>         : EC2 Key Pair name (default: $KeyName)" -ForegroundColor White
    Write-Host "  -SecurityGroupId <String> : Security Group ID (default: $SecurityGroupId)" -ForegroundColor White
    Write-Host "  -SubnetId <String>        : VPC Subnet ID (default: $SubnetId)" -ForegroundColor White
    Write-Host "  -UserDataPath <String>    : Path to custom bootstrap script for 'create'" -ForegroundColor White
    Write-Host "  -Force                    : Skip interactive YES prompts and auto-generate missing passwords" -ForegroundColor White
    Write-Host "  -Help (-h, -?)            : Show this help guide" -ForegroundColor White
    Write-Host ""
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " 6. END-TO-END WORKFLOW CHEATSHEET ($exVm)" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  1. Create VM + User : .\scripts\manage-vm.ps1 create -Name $exVm -NewUser df" -ForegroundColor Yellow
    Write-Host "  2. Check VM Status  : .\scripts\manage-vm.ps1 status -Name $exVm" -ForegroundColor Yellow
    Write-Host "  3. Connect via RDP  : .\scripts\manage-vm.ps1 connect -Name $exVm -Username df" -ForegroundColor Yellow
    Write-Host "  4. Add/Update User  : .\scripts\manage-vm.ps1 modify -Name $exVm -NewUser df" -ForegroundColor Yellow
    Write-Host "  5. Take Screenshot  : .\scripts\manage-vm.ps1 screenshot -Name $exVm" -ForegroundColor Yellow
    Write-Host "  6. Stop When Done   : .\scripts\manage-vm.ps1 stop -Name $exVm" -ForegroundColor Yellow
    Write-Host "  7. Start Next Day   : .\scripts\manage-vm.ps1 start -Name $exVm" -ForegroundColor Yellow
    Write-Host "  8. Factory Reset    : .\scripts\manage-vm.ps1 reset -Name $exVm" -ForegroundColor Yellow
    Write-Host "  9. Purge Completely : .\scripts\manage-vm.ps1 teardown -Name $exVm" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

if ($Help -or $Action -in @("help", "usage")) {
    Show-VMHelp -ExampleName $Name
    return
}

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

# Enforce mandatory VM Name for stop and teardown commands
if (($Action -eq "stop" -or $Action -in @("teardown", "purge", "destroy")) -and [string]::IsNullOrWhiteSpace($Name)) {
    if (-not $Force) {
        $Name = Read-Host "Enter the mandatory VM name to $Action"
    }
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host "[-] The $Action command did not succeed because the VM name is mandatory. Please specify -Name <NAME>." -ForegroundColor Red
        return
    }
}

# If a Name was provided for actions other than create, resolve its active Instance ID
if ((-not [string]::IsNullOrWhiteSpace($Name)) -and $Action -ne "create") {
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
        $vm = Get-VMData -Id $InstanceId
        if (-not $vm) {
            Write-Host "[-] Instance $InstanceId not found." -ForegroundColor Red
            return
        }

        $vmName = if ($Name) { $Name } else { ($vm.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -ExpandProperty Value) }
        if (-not $vmName) { $vmName = $InstanceId }

        if ($vm.State.Name -eq "stopped") {
            Write-Host "[-] Instance '$vmName' ($InstanceId) is already stopped." -ForegroundColor Yellow
            return
        }

        if ($vm.State.Name -eq "stopping") {
            Write-Host "[*] Instance '$vmName' ($InstanceId) is currently stopping. Waiting for 'stopped' state..." -ForegroundColor Yellow
            aws ec2 wait instance-stopped --instance-ids $InstanceId
            Write-Host "[+] Instance '$vmName' ($InstanceId) is now STOPPED. Compute billing has ceased." -ForegroundColor Green
            return
        }

        Write-Host "Stopping instance '$vmName' ($InstanceId)..." -ForegroundColor Yellow
        aws ec2 stop-instances --instance-ids $InstanceId --output table
        Write-Host "Waiting for instance to enter 'stopped' state..." -ForegroundColor Yellow
        aws ec2 wait instance-stopped --instance-ids $InstanceId
        Write-Host "[+] Instance '$vmName' ($InstanceId) is now STOPPED. Compute billing has ceased." -ForegroundColor Green
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
        $vm = Get-VMData -Id $InstanceId
        if (-not $vm) {
            Write-Host "[-] Instance $InstanceId not found." -ForegroundColor Red
            return
        }

        $vmName = if ($Name) { $Name } else { ($vm.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -ExpandProperty Value) }
        if (-not $vmName) { $vmName = $InstanceId }

        if ($vm.State.Name -eq "terminated") {
            Write-Host "[-] Instance '$vmName' ($InstanceId) is already terminated." -ForegroundColor Yellow
            return
        }

        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host " WARNING: PERMANENT INSTANCE TEARDOWN (TERMINATION)" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "This will PERMANENTLY TERMINATE and PURGE instance '$vmName' ($InstanceId)" -ForegroundColor Yellow
        Write-Host "ALL data on the root volume and attached EBS storage will be permanently deleted." -ForegroundColor Yellow
        Write-Host "Compute and storage billing for this instance will cease completely." -ForegroundColor Green

        if (-not $Force) {
            $confirm = Read-Host "`nType 'YES' to permanently purge and delete instance '$vmName'"
            if ($confirm -ne "YES") {
                Write-Host "[-] Teardown aborted by user." -ForegroundColor Gray
                return
            }
        }

        Write-Host "`n[*] Terminating instance '$vmName' ($InstanceId) via AWS CLI..." -ForegroundColor Cyan
        aws ec2 terminate-instances --instance-ids $InstanceId --output table

        Write-Host "Waiting for instance to enter 'terminated' state..." -ForegroundColor Yellow
        aws ec2 wait instance-terminated --instance-ids $InstanceId
        Write-Host "`n[+] Instance '$vmName' ($InstanceId) has been PERMANENTLY TERMINATED and PURGED." -ForegroundColor Green
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


