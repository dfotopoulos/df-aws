# Windows EC2 Remote Desktop (RDP) Connection Guide

This guide walks you through connecting to a Windows EC2 instance in AWS from
your local Windows machine using Remote Desktop Connection (`mstsc`) or AWS
Systems Manager.

---

## Method 1: Direct RDP Connection (Standard)

### Step 1: Retrieve Administrator Password

When a Windows instance is launched in AWS, a random Administrator password is
generated and encrypted using the Key Pair (`.pem`) you selected at launch.

#### Option A: Via AWS Console

1. Open the [Amazon EC2 Console](https://console.aws.amazon.com/ec2/).
2. Click **Instances** in the left menu.
3. Select your Windows instance.
4. Click **Connect** at the top right.
5. Select the **RDP client** tab.
6. Click **Get password**.
7. Click **Browse** and upload your private key file (`.pem` file downloaded
   during key pair creation).
8. Click **Decrypt password**.
9. Note down the **User name** (`Administrator`) and the decrypted **Password**.

#### Option B: Via AWS CLI

```powershell
aws ec2 get-password-data --instance-id <YOUR_INSTANCE_ID> --priv-launch-key path\to\your-keypair.pem
```

> [!NOTE] It takes approximately 4-15 minutes after launching a Windows instance
> before the password is ready to decrypt. If you see "Password not ready", wait
> a few moments and try again.

---

### Step 2: Obtain the Public IP Address

1. In the EC2 console, look at the **Details** pane for your instance.
2. Note the **Public IPv4 address** (e.g. `54.210.xx.xx`).

_If the Public IPv4 address is blank_, the instance was launched in a private
subnet or a subnet without auto-assign public IP enabled. See
[Troubleshooting Checklist](troubleshooting-checklist.md#issue-2-instance-has-no-public-ip-address).

---

### Step 3: Launch Remote Desktop (`mstsc`)

1. Press `Win + R` on your keyboard, type:
    ```cmd
    mstsc
    ```
    and press Enter.
2. In the **Computer** field, enter the **Public IPv4 address** of your
   instance.
3. Click **Connect**.
4. In the Windows Security credentials prompt:
    - Click **More choices** -> **Use a different account**.
    - Username: `Administrator` (or `.\Administrator`)
    - Password: Paste the decrypted password from Step 1.
5. When prompted with a certificate warning ("The identity of the remote
   computer cannot be verified"), check **Don't ask me again for connections to
   this computer** and click **Yes**.

You are now connected to your Windows EC2 desktop!

---

## Connecting with a Different / Custom Windows User (e.g. `df`)

By default, new AWS Windows AMIs only have the `Administrator` account. To
connect as a different user like `df`:

### Step 1: Create the User Inside the Windows VM

While connected as `Administrator`, open **PowerShell as Administrator** on the
Windows VM and run:

```powershell
# 1. Create the user with your chosen password
net user df "YourSecurePassword123!" /add

# 2. Grant Administrator rights (optional, but recommended for dev machines)
net localgroup Administrators df /add

# 3. Grant Remote Desktop permission (MANDATORY for RDP access)
net localgroup "Remote Desktop Users" df /add
```

### Step 2: Connect via `mstsc` as `df`

#### Option A: Via PowerShell Automation Script

```powershell
.\scripts\manage-vm.ps1 connect -Username df
```

This opens Remote Desktop pre-filled with `.\df`. Enter your password
(`YourSecurePassword123!`) when prompted.

#### Option B: Via Standard `mstsc` GUI

1. Run `mstsc /v:ec2-3-79-101-95.eu-central-1.compute.amazonaws.com`
2. When the Windows Security credential prompt appears:
    - Click **More choices** &rarr; **Use a different account**.
    - User name: `.\df` _(The `.\` prefix forces authentication against the
      remote VM rather than your local PC!)_
    - Password: `YourSecurePassword123!`

---

## Method 2: AWS Systems Manager Fleet Manager (No Public IP & No Port 3389 Required)

If your VPC has no public IP or you do not want to open port 3389 to the
internet, AWS Fleet Manager allows browser-based RDP without opening any inbound
ports.

### Prerequisites:

1. The instance has an IAM Role attached with the `AmazonSSMManagedInstanceCore`
   policy.
2. The instance has internet access (via Internet Gateway or NAT Gateway) to
   reach the AWS SSM endpoints.
3. The SSM Agent is running (pre-installed by default on official AWS Windows
   AMIs).

### Steps:

1. Open the
   [AWS Systems Manager Console](https://console.aws.amazon.com/systems-manager/).
2. In the left navigation bar under **Node Management**, select **Fleet
   Manager**.
3. Select your Windows managed node.
4. Click **Node actions** -> **Connect with Remote Desktop**.
5. Choose **Key pair** or enter username (`Administrator`) and decrypted
   password.
6. The Windows desktop will render directly inside your web browser.

---

## Method 3: SSM RDP Port Forwarding via AWS CLI

If you have the AWS CLI and the Session Manager plugin installed, you can tunnel
RDP traffic over HTTPS:

1. Install the Session Manager CLI plugin:
    ```powershell
    Start-Process "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe"
    ```
2. Start port forwarding session on localhost:
    ```powershell
    aws ssm start-session --target <YOUR_INSTANCE_ID> --document-name AWS-StartPortForwardingSession --parameters "portNumber=3389,localPortNumber=53389"
    ```
3. Open `mstsc` and connect to:
    ```cmd
    localhost:53389
    ```
4. Authenticate with `Administrator` and your decrypted password.
