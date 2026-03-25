# workstation-setup.ps1
# Run AFTER DC Part 2 is complete.
# Sets IP, joins domain, configures for user simulation.
# Machine reboots automatically at end.

#requires -RunAsAdministrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "WORKSTATION SETUP" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# ── Configuration ──────────────────────────────────────────────
$ipAddress    = "192.168.1.100"
$subnetMask   = 24
$gateway      = "192.168.1.1"
$dnsServers   = @("192.168.1.10")
$domainName   = "lab.local"
$computerName = "WS01"

# ── Step 1: Static IP ──────────────────────────────────────────
Write-Host "[1/5] Configuring static IP..." -ForegroundColor Yellow

$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
if (-not $adapter) {
    Write-Host "ERROR: No active network adapter found!" -ForegroundColor Red
    exit 1
}

Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress `
    -InterfaceIndex $adapter.ifIndex `
    -IPAddress      $ipAddress `
    -PrefixLength   $subnetMask `
    -DefaultGateway $gateway `
    -ErrorAction Stop

Set-DnsClientServerAddress `
    -InterfaceIndex  $adapter.ifIndex `
    -ServerAddresses $dnsServers

Write-Host "  OK: Static IP set to $ipAddress" -ForegroundColor Green

# ── Step 2: Test DNS ───────────────────────────────────────────
Write-Host "[2/5] Testing DNS resolution..." -ForegroundColor Yellow
try {
    Resolve-DnsName -Name "dc01.lab.local" -ErrorAction Stop | Out-Null
    Write-Host "  OK: DNS resolving dc01.lab.local" -ForegroundColor Green
} catch {
    Write-Host "  WARN: Cannot resolve dc01.lab.local" -ForegroundColor Yellow
    Write-Host "        Check DC is running at 192.168.1.10" -ForegroundColor Yellow
    Write-Host "        Continuing anyway..." -ForegroundColor Yellow
}

# ── Step 3: Rename computer ────────────────────────────────────
Write-Host "[3/5] Renaming computer to $computerName..." -ForegroundColor Yellow
Rename-Computer -NewName $computerName -Force
Write-Host "  OK: Renamed to $computerName" -ForegroundColor Green

# ── Step 4: Local configuration ───────────────────────────────
Write-Host "[4/5] Configuring local settings..." -ForegroundColor Yellow

# Disable Windows Firewall — simplifies attack scenarios
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Write-Host "  OK: Windows Firewall disabled" -ForegroundColor Yellow

# Enable RDP
Set-ItemProperty `
    -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" `
    -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Host "  OK: RDP enabled" -ForegroundColor Green

# High performance power scheme
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
Write-Host "  OK: Power set to High Performance" -ForegroundColor Green

# Disable Windows Defender real-time protection (vulnerability)
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Write-Host "  OK: Defender real-time monitoring disabled (INTENTIONAL VULN)" -ForegroundColor Red

# Create reference file for team
@"
WORKSTATION SETUP COMPLETE
===========================
IP:     192.168.1.100
Name:   WS01
Domain: lab.local

DOMAIN USERS (login as lab\username):
  john.smith    / Password123!
  jane.doe      / Password123!
  bob.wilson    / Password123!  [DOMAIN ADMIN]
  alice.johnson / Password123!
  edward.nygma  / password123   [WEAK - intentional]
  bruce.wayne   / Batman!       [GUESSABLE - intentional]

FILE SHARES:
  \\fileserver.lab.local\Public      (everyone)
  \\fileserver.lab.local\Sensitive   (everyone - misconfigured)
  \\fileserver.lab.local\HR          (HR_Users only)
  \\fileserver.lab.local\IT          (IT_Users only)

INTENTIONAL VULNERABILITIES:
  - Firewall disabled
  - Defender disabled
  - Weak domain user passwords
  - RDP exposed to internal network
"@ | Out-File -FilePath "C:\Users\Public\Desktop\README.txt" -Encoding utf8

# ── Step 5: Join domain ────────────────────────────────────────
Write-Host "[5/5] Joining domain $domainName..." -ForegroundColor Yellow

$domainCred = New-Object System.Management.Automation.PSCredential(
    "LAB\Administrator",
    ("Admin123!" | ConvertTo-SecureString -AsPlainText -Force)
)

try {
    Add-Computer `
        -DomainName $domainName `
        -Credential $domainCred `
        -Restart `
        -Force `
        -ErrorAction Stop
    Write-Host "  OK: Domain join initiated. Rebooting..." -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Domain join failed: $_" -ForegroundColor Red
    Write-Host "         Check DC is up and Admin123! is correct" -ForegroundColor Red

    # Fallback — schedule domain join after reboot
    $fallbackScript = @"
`$cred = New-Object System.Management.Automation.PSCredential(
    'LAB\Administrator',
    ('Admin123!' | ConvertTo-SecureString -AsPlainText -Force)
)
Add-Computer -DomainName '$domainName' -Credential `$cred -Force
Restart-Computer -Force
"@
    $fallbackPath = "C:\Windows\Temp\JoinDomain.ps1"
    $fallbackScript | Out-File -FilePath $fallbackPath -Encoding utf8

    $action    = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$fallbackPath`""
    $trigger   = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask `
        -TaskName  "JoinDomainFallback" `
        -Action    $action `
        -Trigger   $trigger `
        -Principal $principal `
        -Force | Out-Null

    Write-Host "  Fallback scheduled. Rebooting in 30 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Restart-Computer -Force
}
```

---

### Script 6 of 6 — Run order reminder (save as README.txt on USB)
```
WINDOWS VM SETUP - RUN ORDER
==============================

STEP 1: DOMAIN CONTROLLER
  Boot DC VM
  Transfer USB contents
  Open PowerShell as Administrator
  Run: powershell.exe -ExecutionPolicy Bypass -File dc-setup-part1.ps1
  Wait: machine reboots automatically
  Wait: dc-setup-part2.ps1 runs automatically after reboot
  Verify: open PowerShell and run Get-ADUser -Filter * to confirm users exist

STEP 2: FILE SERVER
  Boot File Server VM
  Transfer USB contents
  Open PowerShell as Administrator
  Run: powershell.exe -ExecutionPolicy Bypass -File fileserver-setup-part1.ps1
  Wait: machine reboots automatically
  Wait: fileserver-setup-part2.ps1 runs automatically after reboot
  Verify: open PowerShell and run Get-SmbShare to confirm shares exist

STEP 3: WORKSTATION
  Boot Workstation VM
  Transfer USB contents
  Open PowerShell as Administrator
  Run: powershell.exe -ExecutionPolicy Bypass -File workstation-setup.ps1
  Wait: machine reboots and joins domain automatically

PASSWORDS REFERENCE:
  DC Administrator:     Admin123!   (set during Windows Server install)
  Safe Mode:            P@ssw0rd123!
  Domain join account:  LAB\Administrator / Admin123!
  edward.nygma:         password123 (weak - intentional)
  bruce.wayne:          Batman! (guessable - intentional)
  svc_backup:           SvcP@ss123 (in Domain Admins - intentional)
  svc_mssql:            backup123 (weak - intentional)
  All other users:      Password123!

IMPORTANT NOTES:
  - DC must be fully running before File Server or Workstation scripts run
  - Admin123! must match the actual DC Administrator account password
  - If domain join fails, check DC is reachable at 192.168.1.10
  - All scripts are air-gap safe - no internet required
