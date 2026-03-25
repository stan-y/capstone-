# fileserver-setup-part1.ps1
# Run after DC Part 2 is complete.
# Installs role, creates files, joins domain, reboots.
# After reboot run fileserver-setup-part2.ps1

#requires -RunAsAdministrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "FILE SERVER SETUP - PART 1 of 2" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# ── Configuration ──────────────────────────────────────────────
$ipAddress  = "192.168.1.20"
$subnetMask = 24
$gateway    = "192.168.1.1"
$dnsServers = @("192.168.1.10")
$domainName = "lab.local"

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
    -InterfaceIndex $adapter.ifIndex `
    -ServerAddresses $dnsServers

Write-Host "  OK: Static IP set to $ipAddress" -ForegroundColor Green

# ── Step 2: Rename ─────────────────────────────────────────────
Write-Host "[2/5] Renaming computer to FILESERVER..." -ForegroundColor Yellow
Rename-Computer -NewName "FILESERVER" -Force
Write-Host "  OK: Renamed to FILESERVER (takes effect after reboot)" -ForegroundColor Green

# ── Step 3: Install File Server role ──────────────────────────
# Done before domain join so no dependency on DC being reachable
Write-Host "[3/5] Installing File Server role..." -ForegroundColor Yellow

Install-WindowsFeature `
    -Name FS-FileServer `
    -IncludeManagementTools `
    -Source "C:\Windows\WinSxS" `
    -ErrorAction Stop | Out-Null

Write-Host "  OK: File Server role installed" -ForegroundColor Green

# ── Step 4: Create directory structure and files ───────────────
# Done before domain join — no domain dependency for file creation
Write-Host "[4/5] Creating directories and sensitive files..." -ForegroundColor Yellow

$shareBase = "C:\Shares"
$dirs = @("HR","IT","Finance","Public","Sensitive","Executives","Departmental")

foreach ($dir in $dirs) {
    New-Item -Path (Join-Path $shareBase $dir) -ItemType Directory -Force | Out-Null
    Write-Host "      Created: $shareBase\$dir" -ForegroundColor Green
}

# HR — salary data (sensitive)
@"
EMPLOYEE SALARY DATA - CONFIDENTIAL
=====================================
John Smith:     $95,000
Jane Doe:       $110,000
Bob Wilson:     $145,000
Alice Johnson:  $135,000
Charlie Brown:  $85,000
Diana Prince:   $250,000
Edward Nygma:   $105,000
Bruce Wayne:    $1,000,000

This file is for training purposes only.
DO NOT DISTRIBUTE
"@ | Out-File -FilePath "C:\Shares\HR\salaries_2026.txt" -Encoding utf8

# IT — database credentials (high value target)
@"
DATABASE CONNECTIONS - PRODUCTION
===================================
DB_SERVER:   dc01.lab.local
DB_NAME:     corp_db
DB_USER:     sa
DB_PASS:     SqlAdmin123!
PORT:        1433

BACKUP SERVER:  \\fileserver.lab.local\IT\backups
BACKUP_USER:    backup_admin
BACKUP_PASS:    Backup123!

NOTE: SSH keys stored at \\fileserver\IT\ssh_keys\
"@ | Out-File -FilePath "C:\Shares\IT\db_config.txt" -Encoding utf8

# Sensitive — executive memo (accessible to Everyone — vulnerability)
@"
EXECUTIVE MEMO - PROJECT PHOENIX
==================================
To:   Bruce Wayne
From: Diana Prince
Date: March 1, 2026

The acquisition of Wayne Enterprises is proceeding as planned.
Final documents: \\fileserver\Sensitive\merger_final.txt

Investor meeting: March 15, 10:00 AM

This information must remain confidential.
"@ | Out-File -FilePath "C:\Shares\Sensitive\executive_memo.txt" -Encoding utf8

# Public — password file (intentional vulnerability)
@"
PASSWORD REMINDER - DO NOT STORE PASSWORDS HERE!
=================================================
WiFi:       CorpNet / Welcome2026!
Admin:      \\dc01.lab.local / admin / Admin123!
VPN:        vpn.lab.local / bruce.wayne / Batman!
Backup:     \\fileserver / backup_admin / Backup123!
"@ | Out-File -FilePath "C:\Shares\Public\passwords.txt" -Encoding utf8

# Finance — quarterly reports
1..4 | ForEach-Object {
    $revenue = [math]::Round((Get-Random -Minimum 1000000 -Maximum 5000000))
    "Q$_ 2026 Revenue Report`nRevenue: `$$revenue`nStatus: Confidential" |
        Out-File -FilePath "C:\Shares\Finance\Q$_`_report_2026.txt" -Encoding utf8
}

Write-Host "  OK: All files created" -ForegroundColor Green

# ── Step 5: Join domain and schedule Part 2 ───────────────────
Write-Host "[5/5] Joining domain and scheduling Part 2..." -ForegroundColor Yellow

$domainCred = New-Object System.Management.Automation.PSCredential(
    "LAB\Administrator",
    ("Admin123!" | ConvertTo-SecureString -AsPlainText -Force)
)

try {
    Add-Computer `
        -DomainName $domainName `
        -Credential $domainCred `
        -ErrorAction Stop
    Write-Host "  OK: Joined domain $domainName" -ForegroundColor Green
} catch {
    Write-Host "  WARN: Domain join failed: $_" -ForegroundColor Red
    Write-Host "        Verify DC is running at 192.168.1.10" -ForegroundColor Red
    Write-Host "        and Admin123! is the correct Administrator password" -ForegroundColor Red
}

# Schedule Part 2
$part2Path   = "C:\Windows\Temp\fileserver-setup-part2.ps1"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourcePart2 = Join-Path $scriptDir "fileserver-setup-part2.ps1"

if (Test-Path $sourcePart2) {
    Copy-Item $sourcePart2 $part2Path -Force
    Write-Host "  OK: Part 2 copied to $part2Path" -ForegroundColor Green
} else {
    Write-Host "  WARN: fileserver-setup-part2.ps1 not found." -ForegroundColor Red
    Write-Host "        Copy it manually to $part2Path before rebooting." -ForegroundColor Red
}

$action    = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$part2Path`""
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal `
    -UserId    "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel  Highest

Register-ScheduledTask `
    -TaskName  "FileServerSetupPart2" `
    -Action    $action `
    -Trigger   $trigger `
    -Principal $principal `
    -Force | Out-Null

Write-Host "  OK: Part 2 scheduled for after reboot" -ForegroundColor Green
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "PART 1 COMPLETE - Rebooting in 30 seconds" -ForegroundColor Cyan
Write-Host "Part 2 runs automatically after reboot" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Start-Sleep -Seconds 30
Restart-Computer -Force
