# Resetting the VM & Purging All Added Applications

This guide provides two distinct methods to purge all added applications (like Microsoft PowerToys, Git, Chrome) and restore the Windows VM to a clean state.

---

## Comparison: Cloud Factory Reset vs. In-Guest App Purge

| Feature | Method 1: Cloud Factory Reset (Root Volume Replacement) | Method 2: In-Guest Application Purge |
| :--- | :--- | :--- |
| **How It Works** | AWS replaces the entire C: drive with a fresh volume from the original AMI | PowerShell script uninstalls packages inside Windows |
| **Purges 100% of Changes?** | **Yes** (Absolute clean slate: files, apps, registry, user accounts) | **App-level only** (uninstalls apps, cleans folders) |
| **Keeps Instance ID & IP?** | **Yes** (Same `i-0c69f686dce985f3f` and same IP `3.79.101.95`) | **Yes** |
| **Time Required** | ~1 to 2 minutes | ~30 to 60 seconds |
| **Recommended For** | Complete factory reset, clean benchmarks, removing broken configs | Quick cleanup of installed tools without rebooting |

---

## Method 1: Cloud Factory Reset (Replace Root Volume)

AWS EC2 Nitro instances feature **Root Volume Replacement** (`create-replace-root-volume-task`). This swaps the active virtual hard drive with a brand new, clean disk generated from the original Windows Server 2025 AMI.

### Option A: Using the Automation Script (Easiest)
From your local PowerShell terminal:
```powershell
.\scripts\manage-vm.ps1 reset
```
*(The script prompts for confirmation, triggers the AWS API task, and monitors it until completion).*

### Option B: Direct AWS CLI Command
```powershell
aws ec2 create-replace-root-volume-task `
    --instance-id i-0c69f686dce985f3f `
    --delete-replaced-root-volume
```

To monitor progress:
```powershell
aws ec2 describe-replace-root-volume-tasks --instance-ids i-0c69f686dce985f3f --output table
```

**What happens:**
1. The old C: drive is detached and deleted (no extra storage fees).
2. A brand-new C: drive is created from the base Windows Server 2025 AMI.
3. All added applications, user accounts (such as `df`), and desktop files are 100% purged.
4. The VM reboots in its original, pristine factory condition.

---

## Method 2: In-Guest Application Purge Script

If you do not want to wipe the whole disk and simply want to uninstall added applications and clean temporary files:

### How to Run:
1. Connect via RDP (e.g. `.\scripts\manage-vm.ps1 connect`).
2. Open **PowerShell as Administrator** inside the remote desktop.
3. Run:
   ```powershell
   # Run the in-guest purge script:
   & "C:\path\to\purge-installed-apps.ps1"
   ```
   *(Or copy the contents of [`scripts/purge-installed-apps.ps1`](../scripts/purge-installed-apps.ps1) directly into PowerShell).*

### What the Purge Script Does:
1. **Uninstalls packages via `winget`**: Silently uninstalls `Microsoft.PowerToys`, `Git.Git`, `Google.Chrome`, and `Microsoft.VisualStudioCode`.
2. **Deletes residual directories**: Removes leftover files in `C:\Program Files\PowerToys` and global start menu shortcuts in `C:\ProgramData`.
3. **Flushes temp directories**: Clears `C:\Windows\Temp` and user temporary folders.
4. **Optional user account removal**: Pass `-KeepUser $false` to also delete the local `df` user account.
