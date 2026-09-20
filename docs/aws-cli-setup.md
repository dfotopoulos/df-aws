# AWS CLI Setup and Authentication

This document explains how to configure the AWS Command Line Interface (CLI) on your Windows machine to interact with your AWS resources.

---

## 1. Prerequisites

- AWS CLI v2 installed (Verify in PowerShell: `aws --version`).
  - *Note: If `aws` is not recognized in an existing terminal session, refresh your path using:*
    ```powershell
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    ```
- An active AWS account.

---

## 2. Generate Access Keys in the AWS Console

> [!CAUTION]
> Never use Root User access keys for day-to-day operations. Always create an IAM User with administrative or EC2-specific permissions.

1. Log in to the [AWS Management Console](https://console.aws.amazon.com/).
2. In the top search bar, type **IAM** and select **IAM (Identity and Access Management)**.
3. In the left navigation pane, choose **Users**, then click **Create user**.
4. Set a username (e.g., `admin-cli` or your name) and click **Next**.
5. Under **Permissions options**, select **Attach policies directly**.
6. Check **AdministratorAccess** (or `AmazonEC2FullAccess` if restricting to EC2/VPC). Click **Next**, then **Create user**.
7. Click on your newly created user name from the list.
8. Go to the **Security credentials** tab.
9. Scroll down to **Access keys** and click **Create access key**.
10. Select **Command Line Interface (CLI)** as the use case, check the confirmation box, and click **Next**.
11. Click **Create access key**.
12. Copy both the **Access key ID** and **Secret access key** (or download the `.csv` file). *You will not be able to view the secret key again after closing this screen.*

---

## 3. Configure Local AWS CLI

Run the following command in PowerShell:

```powershell
aws configure
```

You will be prompted for four values:

| Field | Example Value | Description |
| :--- | :--- | :--- |
| **AWS Access Key ID** | `AKIAIOSFODNN7EXAMPLE` | Generated in Step 2 |
| **AWS Secret Access Key** | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | Generated in Step 2 |
| **Default region name** | `eu-central-1` (or your chosen region) | The region where your VPC was launched (e.g. `us-east-1`, `eu-west-1`) |
| **Default output format** | `json` | Recommended output format |

---

## 4. Verify AWS CLI Connection

Test that your credentials work and can communicate with AWS:

```powershell
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDXXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/admin-cli"
}
```

List your EC2 instances to verify permissions:

```powershell
aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress]" --output table
```
