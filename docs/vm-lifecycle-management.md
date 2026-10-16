# EC2 Windows VM Lifecycle & Management Guide

This guide covers the complete lifecycle of your Windows EC2 instance
(`windows-dev-test-pc`) using both the all-in-one PowerShell CLI tool
([`scripts/manage-vm.ps1`](../scripts/manage-vm.ps1)) and the underlying raw AWS
CLI (`aws ec2` / `aws ssm`) commands.

---

## Quick Reference: All-in-One Management Script (`manage-vm.ps1`)

Run `.\scripts\manage-vm.ps1 help` (or `-Help`) at any time to display the
interactive colorized command reference in your terminal.

| Category             | Action / Alias                     | Example Command (`windows-dev-test-pc`)                                                            | Description                                                                             |
| :------------------- | :--------------------------------- | :------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------- |
| **Help**             | `help` (`usage`, `-Help`, `-h`)    | `.\scripts\manage-vm.ps1 help`                                                                     | Displays the rich built-in command reference, parameters, and AWS CLI equivalents.      |
| **Discovery**        | `status` _(default)_               | `.\scripts\manage-vm.ps1 status -Name windows-dev-test-pc`                                         | Shows Name tag, Instance ID, power state, type, Public IP, and Public DNS.              |
| **Discovery**        | `list`                             | `.\scripts\manage-vm.ps1 list`                                                                     | Lists all EC2 instances in the region in an auto-sized summary table.                   |
| **Discovery**        | `running` (`list -Running`)        | `.\scripts\manage-vm.ps1 running`                                                                  | Lists only currently `running` EC2 instances.                                           |
| **Diagnostics**      | `details`                          | `.\scripts\manage-vm.ps1 details -Name windows-dev-test-pc`                                        | Outputs the complete raw JSON metadata (`aws ec2 describe-instances`) for the VM.       |
| **Diagnostics**      | `screenshot`                       | `.\scripts\manage-vm.ps1 screenshot -Name windows-dev-test-pc`                                     | Captures a live JPG screenshot of the Windows console (`scripts/screenshot.jpg`).       |
| **Power & RDP**      | `start`                            | `.\scripts\manage-vm.ps1 start -Name windows-dev-test-pc`                                          | Starts a stopped VM, waits for `running` state, and prints the new Public IP & DNS.     |
| **Power & RDP**      | `stop` _(requires `-Name`)_        | `.\scripts\manage-vm.ps1 stop -Name windows-dev-test-pc`                                           | Gracefully stops the VM and waits for `stopped` state so compute billing ceases.        |
| **Power & RDP**      | `connect`                          | `.\scripts\manage-vm.ps1 connect -Name windows-dev-test-pc`                                        | Decrypts `Administrator` password to clipboard, updates `.rdp`, and opens `mstsc.exe`.  |
| **Power & RDP**      | `connect -Username <User>`         | `.\scripts\manage-vm.ps1 connect -Name windows-dev-test-pc -Username df`                           | Updates `.rdp` for custom local Windows user `df` and launches `mstsc.exe`.             |
| **Provisioning**     | `create` _(requires `-Name`)_      | `.\scripts\manage-vm.ps1 create -Name windows-dev-test-pc -NewUser df`                             | Launches a new Windows Server 2025 / Win 11 VM, provisions `df`, and polls port `3389`. |
| **Modification**     | `modify` (`modify-vm`, `add-user`) | `.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewUser df`                             | Creates or updates a local Windows Admin & RDP user live via AWS SSM.                   |
| **Modification**     | `modify -NewName <NewName>`        | `.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewName windows-dev-prod-pc`            | Renames the EC2 instance's `Name` tag in-place.                                         |
| **Modification**     | `modify -InstanceType -VolumeSize` | `.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -InstanceType t3.xlarge -VolumeSize 200` | Resizes EC2 compute type (when stopped) and/or expands root `gp3` EBS volume.           |
| **Reset & Teardown** | `reset`                            | `.\scripts\manage-vm.ps1 reset -Name windows-dev-test-pc`                                          | Cloud Factory Reset: replaces root `C:` drive with a fresh disk from the original AMI.  |
| **Reset & Teardown** | `teardown` (`purge`, `destroy`)    | `.\scripts\manage-vm.ps1 teardown -Name windows-dev-test-pc`                                       | Permanently terminates the VM and deletes its root EBS disk (`-Name` is mandatory).     |

---

## Script Parameters Reference

| Parameter          | Aliases             | Default Value                | Used With                               | Description                                                                                                                            |
| :----------------- | :------------------ | :--------------------------- | :-------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------- |
| `-Action`          | _(Position 0)_      | `"status"`                   | All commands                            | Operation to execute (`help`, `status`, `list`, `running`, `start`, `stop`, `connect`, `create`, `modify`, `reset`, `teardown`, etc.). |
| `-Name`            | _(Position 1)_      | _None_                       | All commands                            | Target VM `Name` tag (e.g., `windows-dev-test-pc`). **Mandatory** for `create`, `stop`, and `teardown`/`purge`/`destroy`.              |
| `-InstanceId`      | —                   | `"i-0135755d4c646aae6"`      | All instance-targeted commands          | Explicit EC2 Instance ID. Automatically updated when `create` completes, or resolved dynamically via `-Name`.                          |
| `-Running`         | —                   | `$false`                     | `list`                                  | Filter `list` output to show only `running` EC2 instances.                                                                             |
| `-Username`        | —                   | `"Administrator"`            | `connect`, `modify`                     | Windows OS account used for RDP connection (`connect -Username df`).                                                                   |
| `-NewUser`         | `-User`, `-AddUser` | _None_                       | `create`, `modify`, `add-user`          | Local Windows OS account to create/update and add to `Administrators` and `Remote Desktop Users`.                                      |
| `-NewUserPassword` | `-Password`         | _Interactive / Random_       | `create`, `modify`, `add-user`          | Password for `-NewUser`. Auto-generates a 16-char password if omitted when `-Force` is set or Enter is pressed.                        |
| `-NewName`         | `-Rename`           | _None_                       | `modify`, `modify-vm`                   | New `Name` tag value when renaming an existing instance.                                                                               |
| `-InstanceType`    | —                   | `"t3.large"`                 | `create`, `modify`                      | EC2 instance size (e.g., `t3.large`, `t3.xlarge`). Instance must be `stopped` to change type via `modify`.                             |
| `-VolumeSize`      | —                   | `120`                        | `create`, `modify`                      | Root EBS `gp3` volume size in GB.                                                                                                      |
| `-AmiId`           | —                   | _Latest Win Server 2025_     | `create`                                | Custom AMI ID. If omitted, queries AWS SSM for the latest Windows Server 2025 English Full Base AMI.                                   |
| `-KeyName`         | —                   | `"rsa-sweden-aws"`           | `create`                                | EC2 Key Pair name used to encrypt the Windows Administrator password.                                                                  |
| `-SecurityGroupId` | —                   | `"sg-043f8722ce2abe795"`     | `create`                                | Security Group ID allowing inbound RDP (`TCP 3389`).                                                                                   |
| `-SubnetId`        | —                   | `"subnet-056112256a984f0ab"` | `create`                                | Target public VPC Subnet ID.                                                                                                           |
| `-UserDataPath`    | —                   | _None_                       | `create`                                | Path to a custom bootstrap script passed to `--user-data` during `create`.                                                             |
| `-Force`           | —                   | `$false`                     | `create`, `modify`, `reset`, `teardown` | Skips interactive `YES` confirmation prompts and auto-generates passwords if omitted.                                                  |
| `-Help`            | `-h`, `-?`          | `$false`                     | Any                                     | Prints the built-in rich help guide and exits.                                                                                         |

---

## 0. Viewing Built-in Help (`help`)

You can view the built-in interactive command reference or standard PowerShell
`Get-Help` documentation directly from the terminal:

```powershell
# Rich colorized CLI command reference with windows-dev-test-pc examples & AWS CLI equivalents
.\scripts\manage-vm.ps1 help

# Or using the -Help switch (or customize the example VM name shown in the output)
.\scripts\manage-vm.ps1 -Help
.\scripts\manage-vm.ps1 help -Name windows-dev-test-pc

# Standard PowerShell comment-based help
Get-Help .\scripts\manage-vm.ps1 -Full
```

---

## 1. Starting the VM & Checking Status (`start`, `status`, `screenshot`)

### Why / When to Start:

Start the VM when you need to do development or testing.

### Automated Script Commands:

```powershell
# Start by VM Name tag (or omit -Name to start the default InstanceId)
.\scripts\manage-vm.ps1 start -Name windows-dev-test-pc

# Check current state, Public IP, and Public DNS
.\scripts\manage-vm.ps1 status -Name windows-dev-test-pc
```

### Direct AWS CLI Commands:

```powershell
# Start the instance
aws ec2 start-instances --instance-ids i-0c69f686dce985f3f

# Wait for it to enter the 'running' state
aws ec2 wait instance-running --instance-ids i-0c69f686dce985f3f
```

> [!IMPORTANT] **Dynamic Public IP Warning**: If your instance does not have an
> **Elastic IP**, AWS assigns a **NEW Public IPv4 address** and **NEW Public DNS
> name** every time you stop and start it!
>
> - The Windows Administrator password **does not change**.
> - The [`.\scripts\manage-vm.ps1 connect`](../scripts/manage-vm.ps1) script
>   automatically detects the new IP/DNS on each start.

### Monitoring Boot Status & Health:

1. **Watch System & OS Status Checks (2/2 Passed):**

    ```powershell
    aws ec2 describe-instance-status --instance-ids i-0c69f686dce985f3f --output table
    ```
    - `InstanceStatus: initializing`: Windows is booting up, loading drivers,
      and running `EC2Launch`.
    - `InstanceStatus: ok`: Windows operating system has booted and passed
      reachability checks.

2. **Wait automatically until boot is fully complete:**

    ```powershell
    aws ec2 wait instance-status-ok --instance-ids i-0c69f686dce985f3f
    ```

3. **Take a Live Screenshot of the Windows Screen (`screenshot`):**

    ```powershell
    # Automated via management script (saves scripts\screenshot.jpg and opens it):
    .\scripts\manage-vm.ps1 screenshot -Name windows-dev-test-pc

    # Underlying AWS CLI command:
    aws ec2 get-console-screenshot --instance-id i-0c69f686dce985f3f --output json
    ```

    _(This downloads and displays a real-time capture of the Windows console
    monitor, letting you see the lock screen or boot progress)._

4. **Verify Port 3389 (RDP) Reachability:**
    ```powershell
    Test-NetConnection -ComputerName 3.79.101.95 -Port 3389
    ```
    When `TcpTestSucceeded : True`, the Windows Remote Desktop Service is ready
    for connections.

---

## 2. Stopping the VM (`stop`)

### Why Stop It? (Cost Savings):

- Your instance is a `t3.large` Windows instance.
- Running 24/7 costs roughly **~$95 - $100 / month**.
- When you **STOP** the instance:
    - **EC2 compute billing stops completely** ($0.00/hr for CPU/RAM).
    - You only pay pennies per month for the attached EBS storage
      (~$0.10/GB-month).
    - Always stop the instance when you are finished working!

### Automated Script Command:

> [!NOTE] For safety against accidentally stopping the wrong environment,
> `-Name` is mandatory for `stop` (if omitted without `-Force`, the script
> prompts you interactively for the VM name).

```powershell
.\scripts\manage-vm.ps1 stop -Name windows-dev-test-pc
```

### Direct AWS CLI Commands:

```powershell
# Stop the instance
aws ec2 stop-instances --instance-ids i-0c69f686dce985f3f

# Wait for it to safely shut down
aws ec2 wait instance-stopped --instance-ids i-0c69f686dce985f3f
```

---

## 3. Remote Desktop Connection (`connect`)

### Method A: Automated 1-Click Connect (Recommended)

```powershell
# Connect as built-in Administrator (decrypts password & copies to clipboard automatically)
.\scripts\manage-vm.ps1 connect -Name windows-dev-test-pc

# Connect as a custom local Windows user (e.g. 'df')
.\scripts\manage-vm.ps1 connect -Name windows-dev-test-pc -Username df
```

What this does automatically:

1. Resolves the target VM (`windows-dev-test-pc`) and queries its active Public
   DNS name (even if the IP changed after a restart).
2. When connecting as `Administrator`, decrypts the Windows Administrator
   password via AWS CLI and your PEM key and **copies it to your Windows
   clipboard**.
3. Dynamically updates [`windows-dev-test-pc.rdp`](../windows-dev-test-pc.rdp)
   with the active Public DNS and target username (`.\Administrator` or
   `.\<Username>`).
4. Launches Remote Desktop (`mstsc.exe`)—simply press `Ctrl + V` in the password
   prompt!

### Method B: Manual CLI & `mstsc`

1. Decrypt the password:
    ```powershell
    aws ec2 get-password-data --instance-id i-0c69f686dce985f3f --priv-launch-key "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"
    ```
2. Retrieve current Public DNS name:
    ```powershell
    aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --query "Reservations[0].Instances[0].PublicDnsName" --output text
    ```
3. Launch RDP with the FQDN (avoids Windows 11 Error 0x1808):
    ```cmd
    mstsc /v:<PUBLIC_DNS_NAME>
    ```
4. User name: `.\Administrator` (or `.\df`)

---

## 4. Querying All VM Details (`details`)

### Automated Script Command:

```powershell
.\scripts\manage-vm.ps1 details -Name windows-dev-test-pc
```

### Custom AWS CLI JMESPath Queries:

The AWS CLI provides flexible ways to view specific instance attributes using
`--query` (JMESPath) and output formats (`table`, `json`, `text`):

#### A. Quick Summary Table:

```powershell
aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,PublicDnsName,VpcId]" --output table
```

#### B. Hardware & System Status Checks (2/2 Passed?):

```powershell
aws ec2 describe-instance-status --instance-ids i-0c69f686dce985f3f --output table
```

#### C. Network & Security Group Details:

```powershell
aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --query "Reservations[0].Instances[0].{VpcId:VpcId,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SecurityGroups:SecurityGroups[*].GroupId}" --output json
```

#### D. Attached Storage (EBS Volumes):

```powershell
aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --query "Reservations[0].Instances[0].BlockDeviceMappings" --output json
```

#### E. Complete Raw JSON (Every attribute AWS tracks):

```powershell
aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --output json
```

---

## 5. Listing All or Running VMs in Your Account (`list`, `running`)

You can list all instances or filter specifically for running VMs using the
management script or raw AWS CLI commands:

### Automated Script Commands (Recommended):

```powershell
# List ALL instances (running, stopped, pending, terminated)
.\scripts\manage-vm.ps1 list

# List ONLY running instances
.\scripts\manage-vm.ps1 running

# Or using the -Running switch:
.\scripts\manage-vm.ps1 list -Running
```

### Direct AWS CLI Commands:

To view all virtual machines across your AWS region formatted as a summary
table:

```powershell
aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0],State.Name,InstanceType,PublicIpAddress,PrivateIpAddress,LaunchTime]" --output table
```

- **List only currently running VMs:**
    ```powershell
    aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0],State.Name,PublicIpAddress]" --output table
    ```
- **List only Windows VMs:**
    ```powershell
    aws ec2 describe-instances --filters "Name=platform,Values=windows" --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0],State.Name,PublicIpAddress]" --output table
    ```

---

## 6. Creating a New VM from Scratch (`create`)

You can launch a clean Windows Server 2025 (Windows 11 Desktop Experience)
instance either automatically using `manage-vm.ps1 create` or manually with raw
AWS CLI commands.

### Automated Creation via Management Script (Recommended):

```powershell
# 1. Launch with mandatory VM name (Windows Server 2025 / Windows 11 Desktop, t3.large, 120GB gp3)
.\scripts\manage-vm.ps1 create -Name windows-dev-test-pc

# 2. Launch and automatically provision a custom local Admin & RDP user ('df') via EC2 User Data
.\scripts\manage-vm.ps1 create -Name windows-dev-test-pc -NewUser df

# 3. Non-interactive launch with custom password, larger instance type, and 150 GB volume
.\scripts\manage-vm.ps1 create -Name windows-dev-test-pc -NewUser df -Password "StrongPass!123" -InstanceType t3.xlarge -VolumeSize 150 -Force
```

> [!IMPORTANT] **Mandatory VM Name & Duplicate Protection**: The `-Name`
> parameter is mandatory. If an active VM (`pending`, `running`, `stopping`, or
> `stopped`) with that name already exists, the script aborts safely and prints
> the existing VM's live status rather than launching a duplicate instance.

> [!NOTE] **End-to-End Provisioning Automation**: When `manage-vm.ps1 create`
> runs, it:
>
> 1. Queries AWS SSM Parameter Store for the latest Windows Server 2025 AMI (if
>    `-AmiId` is not explicitly provided).
> 2. Generates an EC2 User Data PowerShell bootstrap script if `-NewUser` is
>    specified (creating the user and adding it to `Administrators` and
>    `Remote Desktop Users`).
> 3. Launches the instance with a `gp3` root volume
>    (`DeleteOnTermination: true`) and waits for the `running` state.
> 4. Automatically updates the default `$InstanceId` in
>    [`scripts/manage-vm.ps1`](../scripts/manage-vm.ps1) and refreshes
>    [`windows-dev-test-pc.rdp`](../windows-dev-test-pc.rdp).
> 5. Polls TCP port `3389` every 5 seconds until Windows finishes booting and
>    Remote Desktop is ready to accept connections, then decrypts and copies the
>    Administrator password to the clipboard.

### Direct AWS CLI Command:

```powershell
aws ec2 run-instances `
    --image-id ami-00c776e9c84f3cb49 `
    --instance-type t3.large `
    --key-name rsa-sweden-aws `
    --security-group-ids sg-043f8722ce2abe795 `
    --subnet-id subnet-056112256a984f0ab `
    --associate-public-ip-address `
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":120,"VolumeType":"gp3","DeleteOnTermination":true}}]' `
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=windows-dev-test-pc}]'
```

### Breakdown of Required Parameters:

- `--image-id ami-00c776e9c84f3cb49`: The official AWS AMI for Microsoft Windows
  Server 2025 English Full Base in `eu-central-1`.
- `--instance-type t3.large`: 2 vCPUs, 8 GiB RAM.
- `--key-name rsa-sweden-aws`: The key pair used to encrypt the Administrator
  password (decrypted locally using `rsa-sweden-aws.pem`).
- `--security-group-ids sg-043f8722ce2abe795`: The existing security group
  permitting inbound TCP 3389 (RDP).
- `--subnet-id subnet-056112256a984f0ab`: The public subnet with the default
  route to your VPC Internet Gateway.
- `--associate-public-ip-address`: Automatically allocates a public IPv4 address
  upon boot.
- `--block-device-mappings`: Attaches a 120 GB `gp3` SSD root volume with
  `DeleteOnTermination: true` (disks are automatically cleaned up when
  terminated).
- `--tag-specifications`: Assigns the human-readable `Name` tag to the instance.

---

## 7. Modifying an Existing VM In-Place (`modify` / `modify-vm` / `add-user`)

The `modify` action (aliases: `modify-vm`, `add-user`) lets you reconfigure an
existing EC2 instance without recreating it. You can run operations individually
or combine them in a single command.

### A. Create or Update a Local Windows User Live via AWS SSM (`-NewUser`)

When the VM is `running` and online in AWS Systems Manager (SSM), `modify`
dispatches an `AWS-RunPowerShellScript` command to create the local Windows user
(or update its password if the account already exists), configure
`PasswordNeverExpires`, add the user to local `Administrators` and
`Remote Desktop Users`, copy the password to your clipboard, and update
`windows-dev-test-pc.rdp`:

```powershell
# Interactive password prompt (or press Enter to auto-generate a 16-char password)
.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewUser df

# Non-interactive with explicit password using the add-user alias
.\scripts\manage-vm.ps1 add-user -Name windows-dev-test-pc -NewUser df -Password "StrongPass!123" -Force

# Non-interactive with auto-generated random password
.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewUser df -Force
```

#### Underlying AWS CLI Equivalent:

```powershell
aws ssm send-command `
    --instance-ids i-0c69f686dce985f3f `
    --document-name "AWS-RunPowerShellScript" `
    --parameters 'commands=["net user df \"StrongPass!123\" /add /y","net localgroup Administrators df /add","net localgroup \"Remote Desktop Users\" df /add"]'
```

### B. Rename the VM (`-NewName` / `-Rename`)

Updates the EC2 `Name` tag on the instance (works in any state):

```powershell
.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewName windows-dev-test-pc-v2

# Underlying AWS CLI command:
aws ec2 create-tags --resources i-0c69f686dce985f3f --tags "Key=Name,Value=windows-dev-test-pc-v2"
```

### C. Resize Compute Instance Type (`-InstanceType`)

Changes the vCPU/RAM tier (e.g., from `t3.large` to `t3.xlarge`). The instance
**must be `stopped`** before changing its instance type:

```powershell
.\scripts\manage-vm.ps1 stop -Name windows-dev-test-pc
.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -InstanceType t3.xlarge
.\scripts\manage-vm.ps1 start -Name windows-dev-test-pc

# Underlying AWS CLI command:
aws ec2 modify-instance-attribute --instance-id i-0c69f686dce985f3f --instance-type "Value=t3.xlarge"
```

### D. Expand Root EBS Volume (`-VolumeSize`)

Expands the attached root `gp3` EBS volume in GB:

```powershell
.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -VolumeSize 200

# Underlying AWS CLI command:
aws ec2 modify-volume --volume-id <ROOT_VOLUME_ID> --size 200
```

---

## 8. Cloud Factory Reset (`reset`)

If you want to wipe all installed software, files, and custom users on the `C:`
drive and return `windows-dev-test-pc` to its pristine original AMI state
**without** changing its Instance ID or Public IP, use `reset` (see also
[Resetting the VM & Purging Applications](vm-reset-and-purge.md)):

```powershell
# Prompts for 'YES' confirmation and monitors root volume replacement task until completion
.\scripts\manage-vm.ps1 reset -Name windows-dev-test-pc

# Or skip confirmation prompt:
.\scripts\manage-vm.ps1 reset -Name windows-dev-test-pc -Force

# Underlying AWS CLI command:
aws ec2 create-replace-root-volume-task --instance-id i-0c69f686dce985f3f --delete-replaced-root-volume
```

---

## 9. Deleting (Terminating) a VM & Understanding Pricing (`teardown`)

In AWS, deleting a virtual machine is called **Terminating** the instance.

### The Crucial Difference: Stopping vs. Terminating

| Action                                | What Happens to VM?                   | Root EBS Disk Data                    | Compute Billing ($/hr) | Disk Billing ($/month)       | Can It Be Restarted?  |
| :------------------------------------ | :------------------------------------ | :------------------------------------ | :--------------------- | :--------------------------- | :-------------------- |
| **Stop** (`stop-instances`)           | Powers down like a physical PC        | **Preserved intact**                  | **STOPS** ($0.00)      | **Continues** (~$0.10/GB/mo) | **Yes** (anytime)     |
| **Terminate** (`terminate-instances`) | **Permanently deleted and discarded** | **Destroyed** (`DeleteOnTermination`) | **STOPS** ($0.00)      | **STOPS** ($0.00)            | **No** (irreversible) |

> [!CAUTION] **Termination is irreversible!** Once you terminate an instance,
> the virtual machine is discarded and its root disk volume is permanently
> wiped. All ongoing charges for both compute and disk storage stop completely.

### Automated Teardown via Management Script:

> [!NOTE] Like `create` and `stop`, the `-Name` parameter is mandatory for
> `teardown` (aliases: `purge`, `destroy`) to prevent accidental deletion.

```powershell
# Terminate and purge windows-dev-test-pc (prompts for 'YES' confirmation)
.\scripts\manage-vm.ps1 teardown -Name windows-dev-test-pc

# Or bypass confirmation prompt using -Force (or alias 'purge' / 'destroy'):
.\scripts\manage-vm.ps1 teardown -Name windows-dev-test-pc -Force
.\scripts\manage-vm.ps1 purge -Name windows-dev-test-pc -Force
```

### Direct AWS CLI Commands to Terminate:

```powershell
# Terminate the instance
aws ec2 terminate-instances --instance-ids i-0c69f686dce985f3f

# Wait for termination to complete
aws ec2 wait instance-terminated --instance-ids i-0c69f686dce985f3f
```
