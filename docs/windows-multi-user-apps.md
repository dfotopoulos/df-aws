# Windows Multi-User Application Guide: Per-User vs. Machine-Wide

When you log in to a Windows instance with a new user account (such as `df`),
you may notice that some applications (like **Microsoft PowerToys**, VS Code, or
Google Chrome) that were visible to `Administrator` are missing from the Start
menu and desktop.

---

## Why This Happens: Per-User vs. Machine-Wide Installations

In Windows, applications can be installed in two different scopes:

| Scope                                | Installation Directory           | Start Menu Location                                                     | Who Can See / Run It?                                  |
| :----------------------------------- | :------------------------------- | :---------------------------------------------------------------------- | :----------------------------------------------------- |
| **Per-User (Default for many apps)** | `C:\Users\<User>\AppData\Local\` | `C:\Users\<User>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs` | **Only that specific user** (`Administrator`)          |
| **Machine-Wide (All Users)**         | `C:\Program Files\`              | `C:\ProgramData\Microsoft\Windows\Start Menu\Programs`                  | **Every user on the VM** (`Administrator`, `df`, etc.) |

When PowerToys or similar apps are installed while logged in as `Administrator`
without specifying the machine scope, the executable and its shortcuts are
placed inside `C:\Users\Administrator\AppData\...`. When user `df` logs in,
Windows generates a fresh, separate user profile directory (`C:\Users\df`), so
the per-user apps from `Administrator` are invisible.

---

## How to Fix: Make PowerToys Available to All Users

### Method 1: Install PowerToys Machine-Wide via `winget` (Recommended)

1. Connect to the instance (as either `df` or `Administrator`).
2. Open **PowerShell as Administrator**.
3. Run the following command with the `--scope machine` flag:
    ```powershell
    winget install Microsoft.PowerToys --scope machine --accept-package-agreements --accept-source-agreements
    ```
4. This installs PowerToys into `C:\Program Files\PowerToys` and registers
   shortcuts in `C:\ProgramData\...`, making PowerToys available to **all
   present and future user accounts**.

---

### Method 2: Check if PowerToys is Already Installed Machine-Wide

If PowerToys was already installed to `C:\Program Files\PowerToys`, only the
desktop shortcut or startup entry is missing for user `df`.

1. Check if the executable exists:
    ```powershell
    Test-Path "C:\Program Files\PowerToys\PowerToys.exe"
    ```
2. If `True`, launch it directly or create a global shortcut for all users:
    ```powershell
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\PowerToys.lnk")
    $shortcut.TargetPath = "C:\Program Files\PowerToys\PowerToys.exe"
    $shortcut.Save()
    ```

---

### Method 3: Best Practice for Installing Software on Multi-User Cloud VMs

When setting up development tools on a Windows EC2 instance for team or
multi-account use, always install software using **machine scope**:

| Application       | Command for Machine-Wide (All Users) Installation                                                                                          |
| :---------------- | :----------------------------------------------------------------------------------------------------------------------------------------- |
| **PowerToys**     | `winget install Microsoft.PowerToys --scope machine`                                                                                       |
| **Git**           | `winget install Git.Git --scope machine`                                                                                                   |
| **VS Code**       | Download and install the **System Installer** (not the User Installer), or run `winget install Microsoft.VisualStudioCode --scope machine` |
| **Google Chrome** | `winget install Google.Chrome --scope machine`                                                                                             |
| **7-Zip**         | `winget install 7zip.7zip --scope machine`                                                                                                 |
