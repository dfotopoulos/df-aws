# IAM Permissions for Managing EC2 Instances

This guide explains how to grant an IAM user the permissions required to manage
your Amazon EC2 Windows instances (start, stop, reboot, view, modify security
groups, and retrieve passwords).

---

## Method 1: Full EC2 Access (Recommended for Administrators)

This grants the IAM user full control over EC2 instances, volumes, security
groups, and key pairs.

### Steps in AWS Management Console:

1. Open the [IAM Users Console](https://console.aws.amazon.com/iam/home#/users).
2. Click on the username (e.g. `df`).
3. Select the **Permissions** tab.
4. Click **Add permissions** &rarr; select **Add permissions** from the
   dropdown.
5. Choose **Attach policies directly**.
6. In the search box, search for:
    ```text
    AmazonEC2FullAccess
    ```
7. Select the checkbox next to `AmazonEC2FullAccess`.
8. Click **Next** at the bottom, then click **Add permissions**.

---

## Method 2: Least-Privilege Policy (Start / Stop / Reboot Only)

If you want the IAM user to manage instances (start, stop, reboot, describe, and
get console output) without allowing them to delete resources or change network
configurations:

### Steps to create a custom policy:

1. In the IAM Console, click **Policies** in the left menu.
2. Click **Create policy**.
3. Select the **JSON** editor and paste the following policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EC2ReadAndDescribe",
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "ec2:GetConsoleOutput",
                "ec2:GetConsoleScreenshot",
                "ec2:GetPasswordData"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EC2StartStopReboot",
            "Effect": "Allow",
            "Action": [
                "ec2:StartInstances",
                "ec2:StopInstances",
                "ec2:RebootInstances"
            ],
            "Resource": "*"
        }
    ]
}
```

4. Click **Next**.
5. Name the policy (e.g. `EC2-Operator-Policy`) and click **Create policy**.
6. Go back to **IAM** &rarr; **Users** &rarr; select the user &rarr; **Add
   permissions** &rarr; **Attach policies directly** &rarr; select
   `EC2-Operator-Policy` &rarr; click **Add permissions**.

---

## Method 3: Enabling AWS CLI Management for the IAM User

Once the IAM user has EC2 permissions:

1. Under the user's details in IAM, click the **Security credentials** tab.
2. Scroll to **Access keys** &rarr; click **Create access key**.
3. Select **Command Line Interface (CLI)** &rarr; check confirmation &rarr;
   click **Next** &rarr; **Create access key**.
4. In your local PowerShell terminal:
    ```powershell
    aws configure
    ```
    Paste the **Access Key ID**, **Secret Access Key**, and enter region
    `eu-central-1` (Europe Frankfurt).
5. Verify access by listing your instances:
    ```powershell
    aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" --output table
    ```
6. Manage instances via CLI:
    - **Stop instance:**
        ```powershell
        aws ec2 stop-instances --instance-ids i-0c69f686dce985f3f
        ```
    - **Start instance:**
        ```powershell
        aws ec2 start-instances --instance-ids i-0c69f686dce985f3f
        ```
    - **Reboot instance:**
        ```powershell
        aws ec2 reboot-instances --instance-ids i-0c69f686dce985f3f
        ```
