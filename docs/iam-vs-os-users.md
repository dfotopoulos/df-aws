# AWS IAM Users vs. In-Guest Windows OS Users

A very common source of confusion in cloud computing is the difference between
an **AWS Cloud Identity (IAM)** and an **In-Guest Operating System User
(Windows)**.

---

## 1. The Two Completely Separate Worlds

When you launch a Windows EC2 instance, you are dealing with two separate
identity layers that do not know about each other by default:

```
=============================================================================
 LAYER 1: AWS Cloud Control Plane (Infrastructure Level)
=============================================================================
  Who:   IAM User (e.g. "df") / Root User
  Where: AWS Cloud (AWS Console & AWS CLI)
  Role:  Manages cloud resources (powering VM on/off, resizing disks, VPC)
  Tools: AWS Console, AWS CLI (`aws ec2 ...`), Terraform, SDKs

                              |
       (Provisions & boots)   |
                              v

=============================================================================
 LAYER 2: In-Guest Operating System (Windows Server Level)
=============================================================================
  Who:   Windows OS Users (e.g. "Administrator", "df")
  Where: Inside the VM's Windows SAM database (C:\Windows\System32\config\SAM)
  Role:  Logs into Windows desktop, runs software, manages local files
  Tools: Remote Desktop (`mstsc`), PowerShell inside the VM
```

### Real-World Analogy:

Think of buying a laptop from a computer store:

- Your **store customer account** allows you to order the laptop, turn on
  warranty support, or return it.
- When you boot the laptop, Windows asks you to create a **Windows user
  account**. The Windows OS on the hard drive has no connection to your store
  customer account.

---

## 2. Why Does AWS EC2 Use "Administrator" by Default?

- AWS AMIs (Amazon Machine Images) are pre-packaged Windows Server operating
  systems.
- Every Windows Server installation contains a built-in local user named
  **`Administrator`**.
- When AWS boots the instance for the first time, the `EC2Launch` service
  generates a random secure password for that local `Administrator` account and
  encrypts it using your launch key pair (`rsa-sweden-aws.pem`).
- The AWS IAM user `df` is solely the identity that ordered and controls the AWS
  cloud VM; it is **not** an account inside Windows.

---

## 3. How to Create a Windows User Named `df` Inside the VM

If you want to log in to the Windows desktop as user **`df`** instead of
`Administrator`, you can create a local Windows user named `df` inside the VM.

### Method A: Via PowerShell Inside Remote Desktop

1. Connect via RDP as `Administrator` using:
    ```powershell
    .\scripts\manage-vm.ps1 connect
    ```
2. Once on the Windows desktop, open **PowerShell as Administrator** and run:
    ```powershell
    # 1. Create the local Windows user 'df'
    net user df "YourStrongPassword123!" /add

    # 2. Add 'df' to the local Administrators group
    net localgroup Administrators df /add

    # 3. Add 'df' to Remote Desktop Users
    net localgroup "Remote Desktop Users" df /add
    ```
3. Disconnect from Remote Desktop.
4. Next time you connect via `mstsc`:
    - **User name**: `.\df`
    - **Password**: `YourStrongPassword123!`

---

### Method B: Via AWS Systems Manager (Without Logging In First)

If your instance has an SSM role attached, you can send the user creation
command directly from your local terminal through the AWS CLI:

```powershell
aws ssm send-command `
    --instance-ids i-0c69f686dce985f3f `
    --document-name "AWS-RunPowerShellScript" `
    --parameters 'commands=["net user df YourStrongPassword123! /add","net localgroup Administrators df /add","net localgroup \"Remote Desktop Users\" df /add"]'
```

---

## 4. Summary Table

| Concept                 | AWS IAM User (`df`)                       | Windows OS User (`df` or `Administrator`)          |
| :---------------------- | :---------------------------------------- | :------------------------------------------------- |
| **Location**            | AWS Cloud IAM directory                   | Windows VM disk (`SAM` database)                   |
| **Authentication**      | Access Key / AWS Console password         | Windows password                                   |
| **What it connects to** | AWS CLI & AWS Console                     | Remote Desktop (`mstsc`)                           |
| **Permissions**         | Cloud permissions (`AmazonEC2FullAccess`) | Windows permissions (Local Admin, Files, Registry) |
