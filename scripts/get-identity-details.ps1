<#
.SYNOPSIS
    Retrieves all AWS Account, Root, and IAM User identification information.

.DESCRIPTION
    Queries AWS STS and IAM APIs to extract comprehensive identity parameters,
    security posture (MFA, Access Keys), policies, groups, and sign-in URLs.

.PARAMETER UserName
    The IAM user to inspect. Defaults to the currently authenticated user.

.EXAMPLE
    .\get-identity-details.ps1
    .\get-identity-details.ps1 -UserName df
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$UserName
)

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " AWS Identity & Access Management (IAM) Identification" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Get Current Caller Identity
try {
    $caller = aws sts get-caller-identity --output json | ConvertFrom-Json
    $accountId = $caller.Account
    $callerArn = $caller.Arn
    $callerUserId = $caller.UserId

    if (-not $UserName) {
        if ($callerArn -match "user/(.+)$") {
            $UserName = $matches[1]
        } else {
            $UserName = "df"
        }
    }
} catch {
    Write-Host "[-] Failed to authenticate with AWS CLI. Run 'aws configure' first." -ForegroundColor Red
    exit 1
}

Write-Host "`n[1] Currently Active Caller Identity (AWS STS):" -ForegroundColor Green
Write-Host "    Account ID : $accountId" -ForegroundColor White
Write-Host "    Caller ARN : $callerArn" -ForegroundColor White
Write-Host "    User ID    : $callerUserId" -ForegroundColor White

# 2. AWS Account & Root User Details
Write-Host "`n[2] AWS Account & Root User Identification:" -ForegroundColor Green
Write-Host "    Root User ARN   : arn:aws:iam::${accountId}:root" -ForegroundColor White

$aliases = aws iam list-account-aliases --output json | ConvertFrom-Json
$alias = if ($aliases.AccountAliases.Count -gt 0) { $aliases.AccountAliases[0] } else { "None (using Account ID)" }
Write-Host "    Account Alias   : $alias" -ForegroundColor White

$loginUrl = if ($aliases.AccountAliases.Count -gt 0) {
    "https://$($aliases.AccountAliases[0]).signin.aws.amazon.com/console"
} else {
    "https://${accountId}.signin.aws.amazon.com/console"
}
Write-Host "    IAM Sign-in URL : $loginUrl" -ForegroundColor Cyan

try {
    $summary = (aws iam get-account-summary --output json | ConvertFrom-Json).SummaryMap
    $rootMfa = if ($summary.AccountMFAEnabled -eq 1) { "ENABLED (Protected)" } else { "DISABLED (Action Recommended)" }
    $rootKeys = if ($summary.AccountAccessKeysPresent -eq 0) { "NONE (Best Practice Followed)" } else { "PRESENT (Warning: Delete Root Keys!)" }
    
    Write-Host "    Root MFA Status : $rootMfa" -ForegroundColor $(if ($summary.AccountMFAEnabled -eq 1) { 'Green' } else { 'Red' })
    Write-Host "    Root Access Keys: $rootKeys" -ForegroundColor $(if ($summary.AccountAccessKeysPresent -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Total IAM Users : $($summary.Users)" -ForegroundColor White
    Write-Host "    Total Groups    : $($summary.Groups)" -ForegroundColor White
} catch {
    Write-Host "    [!] Could not fetch account summary (requires iam:GetAccountSummary permission)." -ForegroundColor Yellow
}

# 3. IAM User Identification Details
Write-Host "`n[3] IAM User Details for: '$UserName'" -ForegroundColor Green
try {
    $userData = (aws iam get-user --user-name $UserName --output json | ConvertFrom-Json).User
    Write-Host "    User Name        : $($userData.UserName)" -ForegroundColor White
    Write-Host "    User Unique ID   : $($userData.UserId)" -ForegroundColor White
    Write-Host "    User ARN         : $($userData.Arn)" -ForegroundColor White
    Write-Host "    Path             : $($userData.Path)" -ForegroundColor White
    Write-Host "    Created Date     : $($userData.CreateDate)" -ForegroundColor White
    Write-Host "    Password Last Used: $($userData.PasswordLastUsed)" -ForegroundColor White
} catch {
    Write-Host "    [-] Could not retrieve user profile for $UserName." -ForegroundColor Red
}

# 4. Attached Policies
Write-Host "`n[4] Attached IAM Policies:" -ForegroundColor Green
try {
    $policies = aws iam list-attached-user-policies --user-name $UserName --output json | ConvertFrom-Json
    if ($policies.AttachedPolicies.Count -gt 0) {
        foreach ($p in $policies.AttachedPolicies) {
            Write-Host "    - $($p.PolicyName) ($($p.PolicyArn))" -ForegroundColor Cyan
        }
    } else {
        Write-Host "    None attached directly." -ForegroundColor Gray
    }
} catch {
    Write-Host "    [-] Could not list user policies." -ForegroundColor Red
}

# 5. Group Memberships
Write-Host "`n[5] Group Memberships:" -ForegroundColor Green
try {
    $groups = aws iam list-groups-for-user --user-name $UserName --output json | ConvertFrom-Json
    if ($groups.Groups.Count -gt 0) {
        foreach ($g in $groups.Groups) {
            Write-Host "    - Group: $($g.GroupName) (ID: $($g.GroupId), ARN: $($g.Arn))" -ForegroundColor Cyan
        }
    } else {
        Write-Host "    No group memberships." -ForegroundColor Gray
    }
} catch {
    Write-Host "    [-] Could not list user groups." -ForegroundColor Red
}

# 6. Active Access Keys (CLI / API)
Write-Host "`n[6] Active Access Keys:" -ForegroundColor Green
try {
    $keys = aws iam list-access-keys --user-name $UserName --output json | ConvertFrom-Json
    foreach ($k in $keys.AccessKeyMetadata) {
        Write-Host "    - Key ID: $($k.AccessKeyId) [Status: $($k.Status)] Created: $($k.CreateDate)" -ForegroundColor $(if ($k.Status -eq 'Active') { 'Green' } else { 'Yellow' })
    }
} catch {
    Write-Host "    [-] Could not list access keys." -ForegroundColor Red
}

# 7. MFA Devices
Write-Host "`n[7] Assigned MFA Devices:" -ForegroundColor Green
try {
    $mfas = aws iam list-mfa-devices --user-name $UserName --output json | ConvertFrom-Json
    if ($mfas.MFADevices.Count -gt 0) {
        foreach ($m in $mfas.MFADevices) {
            Write-Host "    - Serial/ARN: $($m.SerialNumber) (Enabled: $($m.EnableDate))" -ForegroundColor Green
        }
    } else {
        Write-Host "    No MFA devices assigned." -ForegroundColor Yellow
    }
} catch {
    Write-Host "    [-] Could not list MFA devices." -ForegroundColor Red
}

# 8. User Tags
Write-Host "`n[8] User Tags:" -ForegroundColor Green
try {
    $tags = aws iam list-user-tags --user-name $UserName --output json | ConvertFrom-Json
    if ($tags.Tags.Count -gt 0) {
        foreach ($t in $tags.Tags) {
            Write-Host "    - $($t.Key) = '$($t.Value)'" -ForegroundColor Gray
        }
    } else {
        Write-Host "    No tags assigned." -ForegroundColor Gray
    }
} catch {
    Write-Host "    [-] Could not list user tags." -ForegroundColor Red
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " End of Identity Information" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
