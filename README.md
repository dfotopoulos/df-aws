# AWS Windows EC2 Remote Desktop (RDP) & VPC Guide

This repository contains step-by-step documentation, architectural explanations,
and diagnostic scripts for connecting to a Windows EC2 instance running in an
Amazon Web Services (AWS) Virtual Private Cloud (VPC).

---

## Quick Navigation

- [Resetting the VM & Purging Applications](docs/vm-reset-and-purge.md):
  Cloud-native root volume replacement (factory reset) vs. in-guest app purging.
- [Windows Multi-User Application Guide](docs/windows-multi-user-apps.md): Why
  apps like PowerToys disappear in new user accounts (Per-User vs. Machine-Wide
  scopes) and how to install for all users.
- [IAM Cloud Users vs. Windows OS Users](docs/iam-vs-os-users.md): Why RDP uses
  `Administrator` rather than `df`, and how to create a `df` Windows account
  inside the VM.
- [VM Lifecycle & CLI Management Guide](docs/vm-lifecycle-management.md):
  Complete reference for [`scripts/manage-vm.ps1`](scripts/manage-vm.ps1) and
  underlying AWS CLI commands (`help`, `status`, `list`, `running`, `start`,
  `stop`, `connect`, `create`, `modify`, `add-user`, `reset`, `screenshot`,
  `teardown`).
- [AWS Mobile App Sign-In Guide](docs/aws-mobile-app-setup.md): Exact fields and
  values for logging into the AWS Console Android app.
- [Root User vs. IAM User Guide](docs/aws-root-vs-iam.md): Explains the
  differences between your Root account and IAM user `df`, least-privilege
  concepts, and inspection commands.
- [Executed Commands & Action Log](docs/executed-commands-log.md): Complete
  chronological record of every command executed and its technical purpose.
- [AWS Console Quickstart (Console Only)](docs/console-quickstart.md):
  Step-by-step console guide for instances launched via root user.
- [IAM EC2 Management Guide](docs/iam-ec2-management.md): How to grant an IAM
  user permissions to manage and operate EC2 instances.
- [AWS CLI Configuration Guide](docs/aws-cli-setup.md): How to create IAM
  credentials and configure your local AWS CLI.
- [Windows RDP Connection Guide](docs/windows-rdp-connection-guide.md):
  Step-by-step instructions to connect via Remote Desktop (`mstsc`) and AWS
  Systems Manager.
- [Troubleshooting & Diagnostics](docs/troubleshooting-checklist.md):
  Comprehensive checklist covering VPC routes, Internet Gateways, Security
  Groups, Public IPs, and Windows password retrieval.
- [Diagnostic Script](scripts/diagnose-ec2-windows.ps1): Automated PowerShell
  script using AWS CLI to detect why your instance is unreachable.

---

## All-in-One VM Management CLI ([`scripts/manage-vm.ps1`](scripts/manage-vm.ps1))

Manage the entire lifecycle of your Windows EC2 instance (e.g.,
`windows-dev-test-pc`) from PowerShell:

```powershell
# Display the rich interactive help reference (with windows-dev-test-pc & AWS CLI examples)
.\scripts\manage-vm.ps1 help

# Check VM status or list all / running instances
.\scripts\manage-vm.ps1 status -Name windows-dev-test-pc
.\scripts\manage-vm.ps1 list
.\scripts\manage-vm.ps1 running

# Create a new Windows Server 2025 / Win 11 VM and bootstrap local admin user 'df'
.\scripts\manage-vm.ps1 create -Name windows-dev-test-pc -NewUser df

# Start, stop (halts compute billing), or connect via Remote Desktop (mstsc.exe)
.\scripts\manage-vm.ps1 start -Name windows-dev-test-pc
.\scripts\manage-vm.ps1 connect -Name windows-dev-test-pc
.\scripts\manage-vm.ps1 connect -Name windows-dev-test-pc -Username df
.\scripts\manage-vm.ps1 stop -Name windows-dev-test-pc

# Modify an existing VM in-place (add/update OS user via SSM, rename, or resize CPU/disk)
.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewUser df
.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -NewName windows-dev-test-pc-v2
.\scripts\manage-vm.ps1 modify -Name windows-dev-test-pc -InstanceType t3.xlarge -VolumeSize 200

# Capture a live console screenshot, factory-reset root disk, or permanently teardown
.\scripts\manage-vm.ps1 screenshot -Name windows-dev-test-pc
.\scripts\manage-vm.ps1 reset -Name windows-dev-test-pc
.\scripts\manage-vm.ps1 teardown -Name windows-dev-test-pc
```

See the full
[VM Lifecycle & CLI Management Guide](docs/vm-lifecycle-management.md) for all
parameters and raw `aws ec2` / `aws ssm` equivalents.

---

## Why Windows EC2 Instances Fail to Connect (Top 6 Reasons)

When a new AWS account and VPC are created, Windows instances commonly fail to
connect via Remote Desktop for one of the following reasons:

```
+-----------------------------------------------------------------------------------+
| 1. Missing Internet Gateway (IGW) or Route                                        |
|    VPC subnet route table must have: 0.0.0.0/0 -> igw-xxxx                        |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 2. No Public IPv4 Address                                                         |
|    Subnet must either auto-assign public IPs, or an Elastic IP must be allocated. |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 3. Security Group Blocking Port 3389                                              |
|    Inbound rule must allow TCP 3389 from your public IP address (CIDR /32).       |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 4. Instance Still Initializing (Status Checks: 2/2)                                |
|    Windows EC2 instances take 3-6 minutes to initialize EC2Launch/EC2Config.      |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 5. Missing / Incorrect Administrator Password                                     |
|    Password must be decrypted using the private key (.pem) chosen at launch.      |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 6. Network ACL (NACL) Restrictions                                                |
|    VPC Network ACLs must permit inbound 3389 and outbound ephemeral ports.        |
+-----------------------------------------------------------------------------------+
```

---

## Connection Options

| Method                                  | Public IP Needed? | Port 3389 Open to Internet? |    Key Pair (.pem) Required?     | Best For                           |
| :-------------------------------------- | :---------------: | :-------------------------: | :------------------------------: | :--------------------------------- |
| **Direct RDP (`mstsc`)**                |      **Yes**      | Yes (restricted to your IP) |               Yes                | Quickest traditional setup         |
| **AWS Systems Manager (Fleet Manager)** |      **No**       |             No              | No (can use Fleet Manager login) | Most secure, zero open ports       |
| **SSM Port Forwarding (`aws ssm`)**     |      **No**       | No (tunnels localhost:3389) |               Yes                | Secure RDP through AWS CLI session |

---

## Getting Started

1. Set up your AWS CLI: See
   [AWS CLI Configuration Guide](docs/aws-cli-setup.md).
2. Run the diagnostic script:
    ```powershell
    .\scripts\diagnose-ec2-windows.ps1
    ```
3. Follow the steps in
   [Windows RDP Connection Guide](docs/windows-rdp-connection-guide.md).
