# EC2 Windows VM Lifecycle & Management Guide

This guide teaches you how to manage your Windows EC2 instance
(`windows-dev-test-pc`, ID: `i-0c69f686dce985f3f`) using both direct AWS CLI
commands and the included automation scripts.

---

## Quick Reference: All-in-One Management Script

You can perform all operations using the included PowerShell script:

| Action               | Command                                     |
| :------------------- | :------------------------------------------ |
| **Check Status**     | `.\scripts\manage-vm.ps1 status`            |
| **List All VMs**     | `.\scripts\manage-vm.ps1 list`              |
| **List Running VMs** | `.\scripts\manage-vm.ps1 running`           |
| **Start VM**         | `.\scripts\manage-vm.ps1 start`             |
| **Stop VM**          | `.\scripts\manage-vm.ps1 stop`              |
| **Connect (RDP)**    | `.\scripts\manage-vm.ps1 connect`           |
| **Full Details**     | `.\scripts\manage-vm.ps1 details`           |
| **Create VM**        | `.\scripts\manage-vm.ps1 create -Name <VM>` |
| **Teardown VM**      | `.\scripts\manage-vm.ps1 teardown`          |

---

## 1. Starting the VM

### Why / When to Start:

Start the VM when you need to do development or testing.

### Direct AWS CLI Command:

```powershell
aws ec2 start-instances --instance-ids i-0c69f686dce985f3f
```

### Wait for it to become running:

```powershell
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

3. **Take a Live Screenshot of the Windows Screen:**

    ```powershell
    # Automated via management script:
    .\scripts\manage-vm.ps1 screenshot
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

## 2. Stopping the VM

### Why Stop It? (Cost Savings):

- Your instance is a `t3.large` Windows instance.
- Running 24/7 costs roughly **~$95 - $100 / month**.
- When you **STOP** the instance:
    - **EC2 compute billing stops completely** ($0.00/hr for CPU/RAM).
    - You only pay pennies per month for the attached EBS storage
      (~$0.10/GB-month).
    - Always stop the instance when you are finished working!

### Direct AWS CLI Command:

```powershell
aws ec2 stop-instances --instance-ids i-0c69f686dce985f3f
```

### Wait for it to safely shut down:

```powershell
aws ec2 wait instance-stopped --instance-ids i-0c69f686dce985f3f
```

---

## 3. Remote Desktop Connection (RDP)

### Method A: Automated 1-Click Connect (Recommended)

```powershell
.\scripts\manage-vm.ps1 connect
```

What this does automatically:

1. Queries the active Public DNS name (even if the IP changed after a restart).
2. Decrypts the Windows Administrator password via AWS CLI and your PEM key.
3. **Copies the password to your Windows clipboard**.
4. Generates an `.rdp` file and opens Remote Desktop (`mstsc.exe`).
5. You only need to press `Ctrl + V` in the password box!

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
4. User name: `.\Administrator`

---

## 4. Querying All VM Details via AWS CLI

The AWS CLI provides powerful ways to view instance details using the `--query`
flag (JMESPath queries) and different output formats (`table`, `json`, `text`).

### A. Quick Summary Table:

```powershell
aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,PublicDnsName,VpcId]" --output table
```

### B. Hardware & System Status Checks (2/2 Passed?):

```powershell
aws ec2 describe-instance-status --instance-ids i-0c69f686dce985f3f --output table
```

### C. Network & Security Group Details:

```powershell
aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --query "Reservations[0].Instances[0].{VpcId:VpcId,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SecurityGroups:SecurityGroups[*].GroupId}" --output json
```

### D. Attached Storage (EBS Volumes):

```powershell
aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --query "Reservations[0].Instances[0].BlockDeviceMappings" --output json
```

### E. Complete Raw JSON (Every attribute AWS tracks):

```powershell
aws ec2 describe-instances --instance-ids i-0c69f686dce985f3f --output json
```

---

## 5. Listing All or Running VMs in Your Account

You can list all instances or filter specifically for running VMs using the
management script or raw AWS CLI commands:

### Automated Script Commands (Recommended):

```powershell
# List ALL instances (running, stopped, pending)
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

## 6. Deleting (Terminating) a VM & Understanding Pricing

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

```powershell
# Terminate and purge the default instance (prompts for confirmation)
.\scripts\manage-vm.ps1 teardown

# Or bypass confirmation prompt:
.\scripts\manage-vm.ps1 teardown -Force

# Or specify a different instance:
.\scripts\manage-vm.ps1 teardown -InstanceId i-xxxx -Force
```

### Direct AWS CLI Command to Terminate:

```powershell
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>
```

### Wait for termination to complete:

```powershell
aws ec2 wait instance-terminated --instance-ids <INSTANCE_ID>
```

---

## 7. Creating an Identical VM from Scratch

You can launch a clean Windows instance either automatically using
`manage-vm.ps1 create` or manually with raw AWS CLI commands.

### Automated Creation via Management Script (Recommended):

```powershell
# Launch with mandatory VM name (Windows Server 2025 / Windows 11 Desktop, t3.large, 120GB gp3)
.\scripts\manage-vm.ps1 create -Name windows-dev-test-pc

# Or customize instance type, volume size, or pass a user-data bootstrap script:
.\scripts\manage-vm.ps1 create -Name my-dev-vm -InstanceType t3.xlarge -VolumeSize 150 -Force
```

> [!IMPORTANT] **Mandatory VM Name & Duplicate Protection**: The `-Name`
> parameter is mandatory. If an active VM with that name already exists, the
> script returns smoothly with an error explaining that creation failed because
> the VM already exists, and prints the existing VM's live status.

> [!NOTE] When `manage-vm.ps1 create` runs, it automatically queries AWS SSM for
> the latest Windows Server 2025 (Windows 11 codebase) AMI, launches the
> instance, waits for it to reach `running` state, polls the RDP port (3389)
> until Windows is fully booted and **available**, updates the default
> `InstanceId` in `manage-vm.ps1`, and refreshes `windows-dev-test-pc.rdp`.

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
- `--instance-type t3.large`: 2 vCPUs, 8 GiB RAM (matching your existing
  instance).
- `--key-name rsa-sweden-aws`: The key pair used to encrypt the Administrator
  password (decrypted locally using `rsa-sweden-aws.pem`).
- `--security-group-ids sg-043f8722ce2abe795`: The existing security group
  permitting inbound TCP 3389 (RDP).
- `--subnet-id subnet-056112256a984f0ab`: The public subnet with the default
  route to your VPC Internet Gateway.
- `--associate-public-ip-address`: Automatically allocates a public IPv4 address
  upon boot.
- `--block-device-mappings`: Attaches a 30 GB gp3 SSD root volume with
  `DeleteOnTermination: true` (disks are automatically cleaned up when
  terminated).
- `--tag-specifications`: Assigns the human-readable `Name` tag to the instance.

### Connecting to the Newly Created VM:

1. Wait 5-8 minutes after running `run-instances` for Windows Server 2025 to
   complete its first boot and initialize `EC2Launch`.
2. Decrypt the Administrator password for the new instance ID:
    ```powershell
    aws ec2 get-password-data --instance-id <NEW_INSTANCE_ID> --priv-launch-key "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"
    ```
3. Connect with `mstsc`:
    ```powershell
    mstsc /v:<NEW_PUBLIC_DNS>
    ```
