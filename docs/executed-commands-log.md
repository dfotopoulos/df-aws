# Comprehensive Log of Executed Commands & Explanations

This document provides a complete chronological log of all diagnostic, configuration, and remediation commands executed to establish Remote Desktop (RDP) connectivity to the Windows EC2 instance in AWS.

---

## Phase 1: Environment Discovery & AWS CLI Refresh

### 1.1 Reloading PowerShell Environment PATH
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
aws --version
```
- **Why**: Windows terminal sessions do not automatically inherit newly installed software until the session is restarted or `$env:Path` is refreshed from the registry.
- **Result**: Successfully recognized `aws-cli/2.36.49 Python/3.14.6 Windows/11 exe/AMD64`.

### 1.2 Inspecting AWS Credentials & Profiles
```powershell
aws configure list
```
- **Why**: Checked if access keys, secrets, or a default region were already configured in `~/.aws/credentials` or `~/.aws/config`.
- **Result**: Initially, no credentials or region were configured.

---

## Phase 2: Key Pair Discovery & Format Conversion (.ppk to .pem)

### 2.1 Locating the Private Key
```powershell
Get-ChildItem -Path "C:\opt\msys\home\df\.ssh" -Filter "*rsa-sweden*"
```
- **Why**: Found the key pair file chosen when launching the EC2 instance (`rsa-sweden-aws.ppk`).

### 2.2 Inspecting PPK Header
```powershell
Get-Content "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.ppk" -TotalCount 4
```
- **Why**: Identified the key format as PuTTY v2 RSA with no passphrase encryption:
  ```text
  PuTTY-User-Key-File-2: ssh-rsa
  Encryption: none
  Comment: rsa-sweden-aws
  ```

### 2.3 Converting PuTTY (.ppk) to OpenSSH / PEM (.pem)
```powershell
python .\scripts\convert-ppk-to-pem.py "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.ppk" "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"
```
- **Why**: **AWS EC2 password decryption strictly requires an OpenSSH/PEM RSA private key (`.pem`)** formatted in PKCS#1 ASN.1 DER with header `-----BEGIN RSA PRIVATE KEY-----`. The AWS Console and CLI reject PuTTY `.ppk` files.
- **How it works**: The script extracts the RSA integers ($n, e, d, p, q, iqmp, dmp1, dmq1$) from the PPK payload, serializes them to PKCS#1 DER, base64 encodes the binary structure, and writes `rsa-sweden-aws.pem`.

### 2.4 Setting Secure File Permissions (Windows ACLs)
```powershell
icacls "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem" /inheritance:r /grant:r "$($env:USERNAME):(R,W)"
```
- **Why**: OpenSSH and security tools reject private keys that are readable by other users or groups (`BUILTIN\Users`). This command disables inherited permissions and grants exclusive read/write access to your local Windows user account.

### 2.5 Validating Converted PEM Key
```powershell
ssh-keygen -l -f "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"
```
- **Result**: Confirmed key integrity: `2048 SHA256:Tih5PD9qMgNZugku64rVC6Rb6QjqXl1x0NPzpS+y8Go no comment (RSA)`.

---

## Phase 3: Network & Port Reachability Testing

### 3.1 Testing TCP Port 3389 (RDP) from Client to AWS
```powershell
Test-NetConnection -ComputerName 3.79.101.95 -Port 3389
```
- **Why**: Confirmed whether the instance was reachable across the internet over the RDP port before troubleshooting further.
- **Result**:
  ```text
  ComputerName     : 3.79.101.95
  RemoteAddress    : 3.79.101.95
  RemotePort       : 3389
  TcpTestSucceeded : True
  ```
- **Significance**: Proved that the VPC Internet Gateway, Subnet Route Tables, Public IP routing, and Security Group inbound rules were already working.

---

## Phase 4: AWS CLI Configuration & Identity Verification

### 4.1 Correcting Region & Output Format
```powershell
aws configure set region eu-central-1
aws configure set output json
```
- **Why**: Corrected the default region in `~/.aws/config` to Europe (Frankfurt) (`eu-central-1`) where the EC2 instance resides.

### 4.2 Verifying IAM Caller Identity
```powershell
aws sts get-caller-identity
```
- **Why**: Verified that the AWS CLI is communicating with AWS and authenticated under the correct IAM user.
- **Result**:
  ```json
  {
      "UserId": "AIDAUAJRBRSF3FKJEEUIW",
      "Account": "275517639819",
      "Arn": "arn:aws:iam::275517639819:user/df"
  }
  ```

---

## Phase 5: Automated End-to-End Infrastructure Diagnosis

### 5.1 Running the Diagnostic Script
```powershell
.\scripts\diagnose-ec2-windows.ps1
```
This script executed the following underlying AWS API calls:

1. **Enumerate Windows instances:**
   ```powershell
   aws ec2 describe-instances --filters "Name=platform,Values=windows" "Name=instance-state-name,Values=running,pending,stopped"
   ```
   - Target found: `i-0c69f686dce985f3f` (`windows-dev-test-pc`).

2. **Verify hardware and system status checks:**
   ```powershell
   aws ec2 describe-instance-status --instance-ids i-0c69f686dce985f3f
   ```
   - Status: `SystemStatus: ok`, `InstanceStatus: ok`.

3. **Verify Internet Gateway attachment:**
   ```powershell
   aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=vpc-0d61c2aa85d6d2491"
   ```
   - Result: `igw-0d0e0f2d9c0c313d5` is attached.

4. **Verify Subnet Route Table:**
   ```powershell
   aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-xxx"
   ```
   - Result: Default route `0.0.0.0/0` targets `igw-0d0e0f2d9c0c313d5`.

5. **Verify Security Group Inbound Rules:**
   ```powershell
   aws ec2 describe-security-groups --group-ids sg-043f8722ce2abe795
   ```
   - Result: TCP port 3389 allowed.

---

## Phase 6: Decrypting the Windows Administrator Password

### 6.1 Retrieving Password via AWS CLI
```powershell
aws ec2 get-password-data --instance-id i-0c69f686dce985f3f --priv-launch-key "C:\opt\msys\home\df\.ssh\rsa-sweden-aws.pem"
```
- **Why**: EC2 encrypts the initial Administrator password with the public key of `rsa-sweden-aws`. This command downloads the ciphertext and decrypts it locally with the private key.
- **Result**:
  ```json
  {
      "InstanceId": "i-0c69f686dce985f3f",
      "Timestamp": "2026-09-20T09:28:54+00:00",
      "PasswordData": "fP@(@xJFqY5b-0nID6v;.LGdtnYMfSQ%"
  }
  ```

---

## Phase 7: Resolving Windows 11 RDP Error 0x1808

### 7.1 The Problem
When running:
```cmd
mstsc /v:3.79.101.95
```
Windows 11 rejected the connection with **Error 0x1808** because local Microsoft accounts attempt to pass web account authentication tokens when connecting to bare IP addresses.

### 7.2 The Solution
Created a pre-configured `.rdp` file specifying the Fully Qualified Domain Name (FQDN) instead of the bare IP:
- **File**: `windows-dev-test-pc.rdp`
- **Address**: `ec2-3-79-101-95.eu-central-1.compute.amazonaws.com`
- **User**: `.\Administrator`

### 7.3 Automated 1-Click Connection Script
```powershell
.\scripts\connect-rdp.ps1
```
- **Why**: Automates the entire login flow: retrieves the decrypted password, copies it to the Windows clipboard, and launches `mstsc.exe` with the pre-configured `.rdp` settings.
