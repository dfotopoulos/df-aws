# Windows EC2 Remote Connection Troubleshooting Checklist

If you cannot connect to your Windows EC2 instance, work through this step-by-step diagnostic checklist.

---

## Issue 1: Security Group Blocks Port 3389 (Most Common)

For direct Remote Desktop (`mstsc`) connections, AWS Security Groups act as a virtual firewall. Inbound traffic on port 3389 must be explicitly allowed.

### Check via AWS CLI:
```powershell
aws ec2 describe-security-groups --group-ids <SECURITY_GROUP_ID> --query "SecurityGroups[*].IpPermissions"
```

### Fix via AWS Console:
1. Open the [EC2 Console](https://console.aws.amazon.com/ec2/) and select your instance.
2. In the **Security** tab below, click on the **Security Group ID**.
3. Under **Inbound rules**, click **Edit inbound rules**.
4. Click **Add rule**:
   - **Type**: `RDP`
   - **Protocol**: `TCP`
   - **Port range**: `3389`
   - **Source**: Select `My IP` (automatically fills your current public IP, e.g. `203.0.113.5/32`).
5. Click **Save rules**.

> [!WARNING]
> Do NOT set the Source to `Anywhere-IPv4` (`0.0.0.0/0`) unless absolutely necessary for testing, as automated bots continuously scan and brute-force open RDP ports on AWS. Always restrict to your IP.

---

## Issue 2: Instance Has No Public IP Address

If the instance details show **Public IPv4 address: None** or a blank field, the instance cannot be reached directly over the public internet.

### Fix: Allocate and Associate an Elastic IP (EIP)
1. In the EC2 Console, under **Network & Security** in the left menu, select **Elastic IPs**.
2. Click **Allocate Elastic IP address** -> click **Allocate**.
3. Select the newly allocated Elastic IP from the list.
4. Click **Actions** -> **Associate Elastic IP address**.
5. Choose:
   - **Resource type**: `Instance`
   - **Instance**: Select your Windows instance ID.
6. Click **Associate**.
7. Your instance now has a permanent static public IP address. Connect to this IP with `mstsc`.

---

## Issue 3: VPC Subnet Lacks Internet Gateway (IGW) or Route

If the instance has a public IP and security group rule, but the connection times out, the VPC route table likely has no path to the Internet Gateway.

### Step 3A: Verify Internet Gateway is Attached to the VPC
1. Open [VPC Console](https://console.aws.amazon.com/vpc/) -> **Internet Gateways**.
2. Check if an Internet Gateway is attached to your VPC ID (`State: Attached`).
3. *If none exists:*
   - Click **Create internet gateway**, name it (e.g. `my-igw`).
   - Select it, click **Actions** -> **Attach to VPC**, and choose your VPC.

### Step 3B: Verify Route Table has `0.0.0.0/0` Route
1. In VPC Console, go to **Route Tables**.
2. Select the route table associated with your instance's subnet.
3. Check the **Routes** tab:
   - Must contain:
     - **Destination**: `0.0.0.0/0`
     - **Target**: `igw-xxxxxxxxxxxxxxxxx` (your Internet Gateway ID)
4. *If missing:*
   - Click **Edit routes** -> **Add route**.
   - Destination: `0.0.0.0/0`
   - Target: Select **Internet Gateway** -> choose your `igw-...`.
   - Click **Save changes**.

---

## Issue 4: Instance Status Checks Are Not "2/2 Passed"

Windows instances take between 3 and 10 minutes to boot, initialize network drivers, and run `EC2Launch` / `EC2Config`.

### Check via AWS CLI:
```powershell
aws ec2 describe-instance-status --instance-id <YOUR_INSTANCE_ID>
```

### Interpretation:
- `SystemStatus: ok` & `InstanceStatus: ok`: The instance is healthy and ready for RDP.
- `InstanceStatus: initializing`: Windows is still booting. Wait 2-3 minutes.
- `InstanceStatus: impaired`: Windows failed to boot (e.g. driver issue, corrupted storage).
  - Check system log:
    ```powershell
    aws ec2 get-console-output --instance-id <YOUR_INSTANCE_ID> --output text
    ```
  - Get a screenshot of the Windows screen:
    ```powershell
    aws ec2 get-console-screenshot --instance-id <YOUR_INSTANCE_ID> --output text
    ```

---

## Issue 5: Lost Key Pair / Cannot Decrypt Password

If you launched without a key pair or lost your `.pem` private key file:
1. You cannot retrieve the default Administrator password via the standard console decryption.
2. **Resolution Options**:
   - **If AWS SSM Agent is working**: Use **AWS Systems Manager Fleet Manager** to reset the Windows Administrator password without a key pair.
   - **Alternative**: Relaunch the instance with a new key pair that you download and save locally.

---

## Issue 6: Network ACL (NACL) Blocking Traffic

Unlike Security Groups (which are stateful), Network Access Control Lists (NACLs) are stateless.
1. In VPC Console -> **Network ACLs**.
2. Verify:
   - **Inbound Rules**: Allows TCP port 3389 (or All Traffic for rule 100 in default NACLs).
   - **Outbound Rules**: Allows Ephemeral ports (TCP `1024-65535` or All Traffic) to return responses to client.
