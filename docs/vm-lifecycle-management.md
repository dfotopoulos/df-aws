# EC2 Windows VM Lifecycle & Management Guide

This guide teaches you how to manage your Windows EC2 instance (`windows-dev-test-pc`, ID: `i-0c69f686dce985f3f`) using both direct AWS CLI commands and the included automation scripts.

---

## Quick Reference: All-in-One Management Script

You can perform all operations using the included PowerShell script:

| Action | Command |
| :--- | :--- |
| **Check Status** | `.\scripts\manage-vm.ps1 status` |
| **Start VM** | `.\scripts\manage-vm.ps1 start` |
| **Stop VM** | `.\scripts\manage-vm.ps1 stop` |
| **Connect (RDP)** | `.\scripts\manage-vm.ps1 connect` |
| **Full Details** | `.\scripts\manage-vm.ps1 details` |

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

> [!IMPORTANT]
> **Dynamic Public IP Warning**:
> If your instance does not have an **Elastic IP**, AWS assigns a **NEW Public IPv4 address** and **NEW Public DNS name** every time you stop and start it!
> - The Windows Administrator password **does not change**.
> - The [`.\scripts\manage-vm.ps1 connect`](../scripts/manage-vm.ps1) script automatically detects the new IP/DNS on each start.

---

## 2. Stopping the VM

### Why Stop It? (Cost Savings):
- Your instance is a `t3.large` Windows instance.
- Running 24/7 costs roughly **~$95 - $100 / month**.
- When you **STOP** the instance:
  - **EC2 compute billing stops completely** ($0.00/hr for CPU/RAM).
  - You only pay pennies per month for the attached EBS storage (~$0.10/GB-month).
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

The AWS CLI provides powerful ways to view instance details using the `--query` flag (JMESPath queries) and different output formats (`table`, `json`, `text`).

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
