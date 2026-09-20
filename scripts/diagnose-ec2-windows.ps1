<#
.SYNOPSIS
    Diagnoses connectivity issues for an AWS EC2 Windows instance.

.DESCRIPTION
    Inspects AWS CLI configuration, instance state, public IP, subnet routing,
    Internet Gateway, and security group inbound rules for port 3389.

.PARAMETER InstanceId
    (Optional) The EC2 instance ID (e.g. i-0123456789abcdef0). If omitted, lists available Windows instances.

.EXAMPLE
    .\diagnose-ec2-windows.ps1
    .\diagnose-ec2-windows.ps1 -InstanceId i-0123456789abcdef0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$InstanceId
)

# Ensure PATH includes AWS CLI
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " AWS EC2 Windows Remote Desktop (RDP) Diagnostic Tool" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify AWS CLI & Credentials
try {
    $caller = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    if (-not $caller -or -not $caller.Account) {
        throw "No credentials configured"
    }
    Write-Host "[+] AWS CLI Authenticated as Account: $($caller.Account) (Arn: $($caller.Arn))" -ForegroundColor Green
} catch {
    Write-Host "[-] AWS CLI is not configured with active credentials." -ForegroundColor Red
    Write-Host "    Please run 'aws configure' first or consult docs/aws-cli-setup.md" -ForegroundColor Yellow
    exit 1
}

# 2. Identify Target Instance
if (-not $InstanceId) {
    Write-Host "`n[*] Searching for EC2 Windows instances in default region..." -ForegroundColor Yellow
    $instancesJson = aws ec2 describe-instances --filters "Name=platform,Values=windows" "Name=instance-state-name,Values=running,pending,stopped" --output json | ConvertFrom-Json
    
    $found = @()
    if ($instancesJson.Reservations) {
        foreach ($res in $instancesJson.Reservations) {
            foreach ($inst in $res.Instances) {
                $nameTag = ($inst.Tags | Where-Object { $_.Key -eq 'Name' }).Value
                $found += [PSCustomObject]@{
                    InstanceId = $inst.InstanceId
                    Name       = $nameTag
                    State      = $inst.State.Name
                    PublicIp   = $inst.PublicIpAddress
                    VpcId      = $inst.VpcId
                }
            }
        }
    }

    if ($found.Count -eq 0) {
        Write-Host "[-] No Windows instances found in the configured default region." -ForegroundColor Red
        Write-Host "    If your instance is in another region, run: aws configure set region <region-name>" -ForegroundColor Yellow
        Write-Host "    Or specify manually: .\diagnose-ec2-windows.ps1 -InstanceId <id>" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "`nFound Windows Instances:" -ForegroundColor Cyan
    $found | Format-Table -AutoSize | Out-String | Write-Host

    if ($found.Count -eq 1) {
        $InstanceId = $found[0].InstanceId
        Write-Host "[*] Automatically targeting single instance: $InstanceId" -ForegroundColor Green
    } else {
        $InstanceId = Read-Host "Enter the InstanceId to diagnose"
    }
}

Write-Host "`n----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host " Diagnosing Instance: $InstanceId" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

# 3. Retrieve Instance Details
$instData = aws ec2 describe-instances --instance-ids $InstanceId --output json | ConvertFrom-Json
$instance = $instData.Reservations[0].Instances[0]

$state = $instance.State.Name
$publicIp = $instance.PublicIpAddress
$vpcId = $instance.VpcId
$subnetId = $instance.SubnetId
$secGroups = $instance.SecurityGroups

Write-Host "`n[1] Instance State: $state" -ForegroundColor $(if ($state -eq 'running') { 'Green' } else { 'Red' })
if ($state -ne 'running') {
    Write-Host "    [!] Instance must be 'running' to connect. Start it via AWS Console or 'aws ec2 start-instances --instance-ids $InstanceId'." -ForegroundColor Yellow
}

# 4. Status Checks
$statusData = aws ec2 describe-instance-status --instance-ids $InstanceId --output json | ConvertFrom-Json
if ($statusData.InstanceStatuses.Count -gt 0) {
    $sysStatus = $statusData.InstanceStatuses[0].SystemStatus.Status
    $instStatus = $statusData.InstanceStatuses[0].InstanceStatus.Status
    Write-Host "[2] System Reachability: $sysStatus | Instance Status: $instStatus" -ForegroundColor $(if ($sysStatus -eq 'ok' -and $instStatus -eq 'ok') { 'Green' } else { 'Yellow' })
    if ($instStatus -eq 'initializing') {
        Write-Host "    [!] Instance is still booting. Windows setup typically takes 3-5 minutes." -ForegroundColor Yellow
    }
} else {
    Write-Host "[2] Status Checks: Not ready or instance is stopped" -ForegroundColor Yellow
}

# 5. Public IP Check
Write-Host "[3] Public IPv4 Address: $(if ($publicIp) { $publicIp } else { 'NONE' })" -ForegroundColor $(if ($publicIp) { 'Green' } else { 'Red' })
if (-not $publicIp) {
    Write-Host "    [!] Direct RDP requires a public IP. Allocate and associate an Elastic IP (see docs/troubleshooting-checklist.md#issue-2)." -ForegroundColor Yellow
}

# 6. Internet Gateway Check
$igwData = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpcId" --output json | ConvertFrom-Json
$hasIgw = ($igwData.InternetGateways.Count -gt 0)
Write-Host "[4] VPC Internet Gateway: $(if ($hasIgw) { $igwData.InternetGateways[0].InternetGatewayId } else { 'NONE ATTACHED' })" -ForegroundColor $(if ($hasIgw) { 'Green' } else { 'Red' })
if (-not $hasIgw) {
    Write-Host "    [!] VPC $vpcId does not have an Internet Gateway attached. Traffic cannot reach the public internet." -ForegroundColor Red
}

# 7. Route Table Check
$rtData = aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$subnetId" --output json | ConvertFrom-Json
if ($rtData.RouteTables.Count -eq 0) {
    # Check default main route table
    $rtData = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpcId" "Name=association.main,Values=true" --output json | ConvertFrom-Json
}

$hasInternetRoute = $false
if ($rtData.RouteTables.Count -gt 0) {
    $routes = $rtData.RouteTables[0].Routes
    foreach ($r in $routes) {
        if ($r.DestinationCidrBlock -eq "0.0.0.0/0" -and $r.GatewayId -like "igw-*") {
            $hasInternetRoute = $true
            break
        }
    }
}
Write-Host "[5] Subnet Route to 0.0.0.0/0 via IGW: $(if ($hasInternetRoute) { 'YES' } else { 'NO (Private Subnet)' })" -ForegroundColor $(if ($hasInternetRoute) { 'Green' } else { 'Red' })
if (-not $hasInternetRoute) {
    Write-Host "    [!] Subnet $subnetId route table does not route 0.0.0.0/0 to an Internet Gateway." -ForegroundColor Red
}

# 8. Security Group RDP Rule Check
$sgIds = $secGroups.GroupId
$sgData = aws ec2 describe-security-groups --group-ids $sgIds --output json | ConvertFrom-Json

$allowsRdp = $false
$rdpSources = @()

foreach ($sg in $sgData.SecurityGroups) {
    foreach ($perm in $sg.IpPermissions) {
        $matchesPort = ($perm.IpProtocol -eq "-1") -or ($perm.FromPort -le 3389 -and $perm.ToPort -ge 3389)
        if ($matchesPort) {
            $allowsRdp = $true
            foreach ($ipRange in $perm.IpRanges) {
                $rdpSources += "$($sg.GroupId): $($ipRange.CidrIp)"
            }
        }
    }
}

Write-Host "[6] Security Group Inbound TCP 3389: $(if ($allowsRdp) { 'ALLOWED' } else { 'BLOCKED' })" -ForegroundColor $(if ($allowsRdp) { 'Green' } else { 'Red' })
if ($allowsRdp) {
    foreach ($src in $rdpSources) {
        Write-Host "    - Allowed from: $src" -ForegroundColor Cyan
    }
} else {
    Write-Host "    [!] Port 3389 is blocked by security group(s): $($sgIds -join ', ')." -ForegroundColor Red
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Diagnostic Summary & Next Steps" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if ($state -eq 'running' -and $publicIp -and $hasIgw -and $hasInternetRoute -and $allowsRdp) {
    Write-Host "[OK] All AWS networking conditions for RDP are satisfied!" -ForegroundColor Green
    Write-Host "     1. Retrieve your Windows password via EC2 Console or:" -ForegroundColor White
    Write-Host "        aws ec2 get-password-data --instance-id $InstanceId --priv-launch-key <your-key.pem>" -ForegroundColor Gray
    Write-Host "     2. Open Remote Desktop: mstsc.exe /v:$publicIp" -ForegroundColor White
} else {
    Write-Host "[ACTION REQUIRED] Review the red/yellow items above." -ForegroundColor Yellow
    Write-Host "Consult docs/troubleshooting-checklist.md for exact step-by-step resolution." -ForegroundColor White
}
