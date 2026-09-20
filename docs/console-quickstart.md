# AWS Console Quickstart: Windows EC2 & RDP

This guide is designed for instances launched via the AWS Root account or Console without requiring AWS CLI setup.

---

## 4-Step Verification Checklist in AWS Console

### 1. Check Public IPv4 Address
1. Open the [EC2 Instances Console](https://console.aws.amazon.com/ec2/home#Instances:).
2. Select your Windows instance.
3. In the **Details** pane at the bottom, look for **Public IPv4 address**:
   - **If you see an IP address (e.g. `54.x.x.x`)**: Proceed to Step 2.
   - **If it is blank / None**: Your subnet does not automatically assign public IPs.
     - *Quick Fix*: Go to **EC2** -> **Network & Security** -> **Elastic IPs** -> **Allocate Elastic IP address** -> click **Allocate**.
     - Select the new IP -> **Actions** -> **Associate Elastic IP address** -> choose your Instance -> click **Associate**.

---

### 2. Check Security Group (Allow Port 3389)
1. Select your instance and click the **Security** tab below.
2. Click the link under **Security groups** (e.g. `sg-0123456789abcdef0`).
3. Scroll down to **Inbound rules** and check for:
   - **Type**: `RDP`
   - **Protocol**: `TCP`
   - **Port range**: `3389`
4. *If missing or blocked:*
   - Click **Edit inbound rules** -> **Add rule**.
   - Select **Type**: `RDP`.
   - Under **Source**, select **My IP** (AWS automatically detects your public IP).
   - Click **Save rules**.

---

### 3. Retrieve Administrator Password
1. Back on the **Instances** page, select your instance and click **Connect** (top right).
2. Switch to the **RDP client** tab.
3. Click **Get password**.
   - *Note: If it says "Password not ready", wait 5-10 minutes after initial launch.*
4. Click **Upload private key file** and browse to the `.pem` file you downloaded when launching the instance.
5. Click **Decrypt password**.
6. Copy the decrypted **Password**. Note that the **User name** is `Administrator`.

---

### 4. Connect via Remote Desktop (`mstsc`)
1. On your Windows computer, press `Win + R`, type:
   ```cmd
   mstsc
   ```
   and press Enter.
2. In the **Computer** field, paste your **Public IPv4 address**.
3. Click **Connect**.
4. In the Windows Security login prompt:
   - Click **More choices** -> **Use a different account**.
   - Username: `Administrator`
   - Password: *(paste decrypted password)*
5. Accept the certificate warning by clicking **Yes**.
