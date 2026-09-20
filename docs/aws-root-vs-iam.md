# Understanding AWS Root User vs. IAM User

When working with Amazon Web Services (AWS), you will encounter two fundamentally different types of user identities: the **Root User** and **IAM Users**.

---

## 1. Conceptual Comparison

| Feature | Root User (Account Owner) | IAM User (e.g. `df`) |
| :--- | :--- | :--- |
| **How It's Created** | Automatically when the AWS account is registered using an email address. | Created explicitly *inside* the account by an administrator. |
| **Login Identifier** | Email address + Root password. | Account ID (`275517639819`) + Username (`df`) + Password. |
| **ARN Format** | `arn:aws:iam::275517639819:root` | `arn:aws:iam::275517639819:user/df` |
| **Permissions** | **Unrestricted full access** to every service, billing, and resource. Cannot be restricted by policies. | **Explicitly defined**. Starts with zero permissions until policies are attached. |
| **Access Keys (CLI)** | Strongly discouraged. Never generate root access keys. | Recommended for CLI/SDK automation. Can be rotated or revoked anytime. |
| **Best Practice Usage** | Emergency break-glass tasks, changing billing/support plans, or initial setup only. | Day-to-day work (managing EC2, databases, VPCs, development). |

```
+-------------------------------------------------------------------------+
| AWS Account: 275517639819 (Root User: email@example.com)                 |
|   - Complete control, billing, account closure                           |
|                                                                         |
|   +-----------------------------------------------------------------+   |
|   | IAM User: df (arn:aws:iam::275517639819:user/df)                |   |
|   |   - Policy: AmazonEC2FullAccess (Can control EC2, VPC, RDP)     |   |
|   |   - Access Keys: Configured in local AWS CLI                    |   |
|   |   - Cannot modify IAM users (unless granted IAM permission)     |   |
|   +-----------------------------------------------------------------+   |
+-------------------------------------------------------------------------+
```

---

## 2. Why Does AWS Enforce Two Types of Users?

1. **Blast Radius & Security**: If your laptop or CLI credentials are compromised, an attacker only gets the permissions granted to that specific IAM user (e.g., EC2), rather than total ownership of your entire AWS bill, domain, and account.
2. **Revocability**: You can deactivate or delete an IAM user or revoke access keys with one click in the console without losing your AWS account.
3. **Auditing & Tracking**: AWS CloudTrail records exactly which IAM user executed each command (e.g., user `df` stopped an instance at 2:00 PM).

---

## 3. Useful Commands to Inspect Your Identity & Permissions

### Command 1: View Your Current Active Identity
```powershell
aws sts get-caller-identity
```
- **What it does**: Queries AWS Security Token Service (STS) to report who is executing commands.
- **Example Output**:
  ```json
  {
      "UserId": "AIDAUAJRBRSF3FKJEEUIW",
      "Account": "275517639819",
      "Arn": "arn:aws:iam::275517639819:user/df"
  }
  ```
- **Interpretation**: You are authenticated as IAM user `df` inside AWS Account `275517639819`.

---

### Command 2: Checking What Your User Can Do (Least Privilege in Action)
If you try to run:
```powershell
aws iam get-user
```
You will receive:
```text
(AccessDenied) User: arn:aws:iam::275517639819:user/df is not authorized to perform: iam:GetUser
```
- **Why**: User `df` has permissions to control **EC2 virtual machines** (`AmazonEC2FullAccess`), but does **not** have permissions to view or edit **IAM users**.
- This is AWS's security model in action: users only have access to what they have been explicitly granted.

---

### Command 3: How to Grant User `df` Permission to View IAM Information

If you want user `df` to also be able to view IAM users, policies, and account settings:

1. Log in to the [AWS Management Console](https://console.aws.amazon.com/) as **Root**.
2. Go to **IAM** &rarr; **Users** &rarr; **df**.
3. Under **Permissions**, click **Add permissions** &rarr; **Attach policies directly**.
4. Search for:
   - `IAMReadOnlyAccess` (allows viewing users, policies, and credentials without editing them)
   - Or `AdministratorAccess` (allows user `df` to administer everything, including IAM).
5. Click **Next** &rarr; **Add permissions**.

Once added, the following commands will succeed:

```powershell
# View details for user df:
aws iam get-user --user-name df

# View attached policies on user df:
aws iam list-attached-user-policies --user-name df

# View active access keys for user df:
aws iam list-access-keys --user-name df

# View AWS account summary (limits, user count, MFA status):
aws iam get-account-summary
```

---

## 4. How to Switch Between Root and IAM in the Browser

- **To log in as Root**:
  1. Open [https://signin.aws.amazon.com/](https://signin.aws.amazon.com/).
  2. Select **Root user**.
  3. Enter your account owner email and password.

- **To log in as IAM User (`df`)**:
  1. Open [https://signin.aws.amazon.com/](https://signin.aws.amazon.com/).
  2. Select **IAM user**.
  3. Enter your **Account ID**: `275517639819`.
  4. Username: `df`.
  5. Password: *(the console password set for `df`)*.
