# dc-setup-part1.ps1
# Installs AD DS and promotes to DC. Machine reboots automatically.
# After reboot, run dc-setup-part2.ps1

#requires -RunAsAdministrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "DC SETUP - PART 1 of 2" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# ── Configuration ──────────────────────────────────────────────
$ipAddress        = "192.168.1.10"
$subnetMask       = 24
$gateway          = "192.168.1.1"
$dnsServers       = @("127.0.0.1", "192.168.1.10")
$domainName       = "lab.local"
$netbiosName      = "LAB"
$safeModePassword = "P@ssw0rd123!" | ConvertTo-SecureString -AsPlainText -Force

# ── Step 1: Static IP ──────────────────────────────────────────
Write-Host "[1/4] Configuring static IP..." -ForegroundColor Yellow

$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
if (-not $adapter) {
    Write-Host "ERROR: No active network adapter found!" -ForegroundColor Red
    exit 1
}

Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
    -IPAddress $ipAddress `
    -PrefixLength $subnetMask `
    -DefaultGateway $gateway `
    -ErrorAction Stop

Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex `
    -ServerAddresses $dnsServers

Write-Host "  OK: Static IP set to $ipAddress" -ForegroundColor Green

# ── Step 2: Rename computer ────────────────────────────────────
Write-Host "[2/4] Renaming computer to DC01..." -ForegroundColor Yellow
Rename-Computer -NewName "DC01" -Force
Write-Host "  OK: Renamed to DC01 (takes effect after reboot)" -ForegroundColor Green

# ── Step 3: Install AD DS features ────────────────────────────
# Using -Source WinSxS to avoid Windows Update dependency
# Works air-gapped as long as Windows Server was installed
# from a full ISO (which includes all role binaries locally)
Write-Host "[3/4] Installing AD DS features..." -ForegroundColor Yellow

$adFeatures = @(
    "AD-Domain-Services",
    "DNS",
    "RSAT-AD-PowerShell",
    "RSAT-AD-AdminCenter",
    "RSAT-DNS-Server"
)

foreach ($feature in $adFeatures) {
    Write-Host "      Installing $feature..." -ForegroundColor Gray
    $result = Install-WindowsFeature `
        -Name $feature `
        -IncludeManagementTools `
        -Source "C:\Windows\WinSxS" `
        -ErrorAction Stop
    if ($result.Success) {
        Write-Host "      OK: $feature installed" -ForegroundColor Green
    } else {
        Write-Host "      WARN: $feature may not have installed cleanly" -ForegroundColor Yellow
    }
}

# ── Step 4: Promote to Domain Controller ──────────────────────
# -NoRebootOnCompletion lets us schedule part 2 before rebooting
Write-Host "[4/4] Promoting to Domain Controller..." -ForegroundColor Yellow

Install-ADDSForest `
    -DomainName $domainName `
    -DomainNetbiosName $netbiosName `
    -SafeModeAdministratorPassword $safeModePassword `
    -InstallDNS `
    -Force `
    -NoRebootOnCompletion

Write-Host "  OK: DC promotion complete" -ForegroundColor Green

# ── Schedule Part 2 to run automatically after reboot ─────────
Write-Host "Scheduling Part 2 to run after reboot..." -ForegroundColor Yellow

$part2Path = "C:\Windows\Temp\dc-setup-part2.ps1"

# Copy part 2 script to temp location so scheduled task can find it
# Assumes both scripts are in the same directory on USB
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourcePart2 = Join-Path $scriptDir "dc-setup-part2.ps1"

if (Test-Path $sourcePart2) {
    Copy-Item $sourcePart2 $part2Path -Force
    Write-Host "  OK: Part 2 copied to $part2Path" -ForegroundColor Green
} else {
    Write-Host "  WARN: dc-setup-part2.ps1 not found next to this script." -ForegroundColor Red
    Write-Host "        Copy it manually to $part2Path before rebooting." -ForegroundColor Red
}

$action    = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$part2Path`""

$trigger   = New-ScheduledTaskTrigger -AtStartup

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName "DCSetupPart2" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Force | Out-Null

Write-Host "  OK: Scheduled task created" -ForegroundColor Green
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "PART 1 COMPLETE - Rebooting in 30 seconds" -ForegroundColor Cyan
Write-Host "Part 2 will run automatically after reboot" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Start-Sleep -Seconds 30
Restart-Computer -Force
