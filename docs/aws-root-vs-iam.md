# Understanding AWS Root User vs. IAM User

When working with Amazon Web Services (AWS), you will encounter two
fundamentally different types of user identities: the **Root User** and **IAM
Users**.

---

## 1. Conceptual Comparison

| Feature                 | Root User (Account Owner)                                                                               | IAM User (e.g. `df`)                                                              |
| :---------------------- | :------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------------- |
| **How It's Created**    | Automatically when the AWS account is registered using an email address.                                | Created explicitly _inside_ the account by an administrator.                      |
| **Login Identifier**    | Email address + Root password.                                                                          | Account ID (`275517639819`) + Username (`df`) + Password.                         |
| **ARN Format**          | `arn:aws:iam::275517639819:root`                                                                        | `arn:aws:iam::275517639819:user/df`                                               |
| **Permissions**         | **Unrestricted full access** to every service, billing, and resource. Cannot be restricted by policies. | **Explicitly defined**. Starts with zero permissions until policies are attached. |
| **Access Keys (CLI)**   | Strongly discouraged. Never generate root access keys.                                                  | Recommended for CLI/SDK automation. Can be rotated or revoked anytime.            |
| **Best Practice Usage** | Emergency break-glass tasks, changing billing/support plans, or initial setup only.                     | Day-to-day work (managing EC2, databases, VPCs, development).                     |

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

1. **Blast Radius & Security**: If your laptop or CLI credentials are
   compromised, an attacker only gets the permissions granted to that specific
   IAM user (e.g., EC2), rather than total ownership of your entire AWS bill,
   domain, and account.
2. **Revocability**: You can deactivate or delete an IAM user or revoke access
   keys with one click in the console without losing your AWS account.
3. **Auditing & Tracking**: AWS CloudTrail records exactly which IAM user
   executed each command (e.g., user `df` stopped an instance at 2:00 PM).

---

## 3. Retrieving Root User & Account Identification

Because the Root User represents the account itself, its identification is
anchored to the 12-digit **AWS Account ID** and global account metadata.

### 3.1 Retrieve AWS Account ID & Root ARN

```powershell
aws sts get-caller-identity --query "Account" --output text
```

- **Root User ARN format**: `arn:aws:iam::<ACCOUNT_ID>:root` (e.g.
  `arn:aws:iam::275517639819:root`).
- **Significance**: Any policy referencing the root ARN refers to the account
  owner.

---

### 3.2 Retrieve Account Aliases & IAM Sign-In URL

An account alias provides a custom, memorable prefix for your AWS sign-in URL
instead of using the 12-digit Account ID.

```powershell
aws iam list-account-aliases
```

- **Console Sign-In URL Format**:
    - _Without alias_: `https://<ACCOUNT_ID>.signin.aws.amazon.com/console`
      (e.g. `https://275517639819.signin.aws.amazon.com/console`)
    - _With alias_: `https://<ACCOUNT_ALIAS>.signin.aws.amazon.com/console`
- **To create a custom alias (optional):**
    ```powershell
    aws iam create-account-alias --account-alias my-company-cloud
    ```

---

### 3.3 Inspect Root Security Posture (MFA & Access Keys)

You cannot directly query "get root user", but you can query the account summary
to verify that the Root User is secured according to AWS security best
practices:

```powershell
aws iam get-account-summary --query "SummaryMap.{AccountMFAEnabled:AccountMFAEnabled,AccountAccessKeysPresent:AccountAccessKeysPresent,TotalUsers:Users,TotalGroups:Groups}" --output table
```

**Key Security Indicators:**

- `AccountMFAEnabled = 1`: **PASS**. Multi-Factor Authentication is active on
  the Root account.
- `AccountAccessKeysPresent = 0`: **PASS**. No long-lived programmatic access
  keys exist for root (preventing catastrophic API exposure).

---

## 4. Retrieving IAM User (`df`) Identification

IAM users have multiple distinct identification vectors tracked in the IAM
directory:

### 4.1 Basic Profile & Unique User ID

```powershell
aws iam get-user --user-name df
```

**Sample Output:**

```json
{
    "User": {
        "Path": "/",
        "UserName": "df",
        "UserId": "AIDAUAJRBRSF3FKJEEUIW",
        "Arn": "arn:aws:iam::275517639819:user/df",
        "CreateDate": "2026-09-20T09:58:10+00:00",
        "PasswordLastUsed": "2026-09-20T17:44:13+00:00"
    }
}
```

- **`UserName`**: Human-readable name used to log in.
- **`UserId` (`AIDAUAJRBRSF3FKJEEUIW`)**: Unique, immutable internal AWS
  identifier (starts with prefix `AIDA`). Even if you delete and recreate a user
  with the same name, the `UserId` will change.
- **`Arn`**: Full resource name used in IAM policies and permissions boundaries.
- **`PasswordLastUsed`**: Timestamp of the most recent console login.

---

### 4.2 Attached IAM Policies (Permissions)

To inspect which managed policies are attached directly to the user:

```powershell
aws iam list-attached-user-policies --user-name df
```

- Shows policy names and ARNs (e.g. `AdministratorAccess` &rarr;
  `arn:aws:iam::aws:policy/AdministratorAccess`).

To inspect inline custom policies (if any):

```powershell
aws iam list-user-policies --user-name df
```

---

### 4.3 Group Memberships

To view which IAM groups the user belongs to:

```powershell
aws iam list-groups-for-user --user-name df
```

- Returns the group name, Group ID (`AGPA...`), and Group ARN (e.g.
  `arn:aws:iam::275517639819:group/df`).

---

### 4.4 Active Access Keys (CLI & API Credentials)

To list all programmatic API keys issued to the user:

```powershell
aws iam list-access-keys --user-name df
```

- Displays the `AccessKeyId` (e.g. `AKIAUAJRBRSF3HMLY5YG`), its `Status`
  (`Active` or `Inactive`), and `CreateDate`.
- _(Note: Secret Access Keys are never viewable after generation)._

---

### 4.5 Assigned MFA (Multi-Factor Authentication) Devices

To verify whether the IAM user has a hardware key or authenticator app enabled:

```powershell
aws iam list-mfa-devices --user-name df
```

- Displays the MFA Serial Number / ARN (e.g.
  `arn:aws:iam::275517639819:mfa/Zeus`) and the activation timestamp.

---

### 4.6 Assigned User Tags

To view metadata tags assigned to the user:

```powershell
aws iam list-user-tags --user-name df
```

---

## 5. Automated 1-Click Identification Script

You can query all of the above parameters in a single command using the included
script:

```powershell
.\scripts\get-identity-details.ps1
```

_(To inspect a specific username other than the current caller, pass
`-UserName <name>`:)_

```powershell
.\scripts\get-identity-details.ps1 -UserName df
```

---

## 6. How to Retrieve Identification in the AWS Console

### For the Root Account:

1. Click your account name in the top right navigation bar.
2. The 12-digit **Account ID** is shown directly under your name.
3. Click **Account** to view account contact info, organization status, and
   billing details.

### For the IAM User (`df`):

1. In the search bar, open **IAM** &rarr; click **Users** in the left menu.
2. Click on **df**.
3. View the summary tabs:
    - **Summary**: Displays User ARN, Creation time, and Console password
      status.
    - **Permissions**: Displays attached policies.
    - **Groups**: Displays group memberships.
    - **Security credentials**: Displays Access Key IDs, MFA device status, and
      signing certificates.
    - **Tags**: Displays key-value tags.
