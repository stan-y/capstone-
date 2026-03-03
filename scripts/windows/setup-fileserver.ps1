<#
.SYNOPSIS
    Configures Windows Server as File Server with intentionally vulnerable shares
.DESCRIPTION
    Installs File Server role, creates shares with misconfigured permissions
.NOTES
    Run as Administrator
    Version: 1.0
#>

#requires -RunAsAdministrator

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "FILE SERVER SETUP" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration variables
$ipAddress = "192.168.1.20"
$subnetMask = 24
$gateway = "192.168.1.1"
$dnsServers = @("192.168.1.10")
$domainName = "lab.local"

Write-Host "[1/6] Configuring static IP address..." -ForegroundColor Yellow

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

Write-Host "  ✅ Static IP configured: $ipAddress/$subnetMask" -ForegroundColor Green

Write-Host "[2/6] Renaming computer to FILESERVER..." -ForegroundColor Yellow
Rename-Computer -NewName "FILESERVER" -Force
Write-Host "  ✅ Computer renamed to FILESERVER (reboot pending)" -ForegroundColor Green

Write-Host "[3/6] Joining domain $domainName..." -ForegroundColor Yellow

$domainCred = New-Object System.Management.Automation.PSCredential("LAB\Administrator", (ConvertTo-SecureString "Admin123!" -AsPlainText -Force))

try {
    Add-Computer -DomainName $domainName -Credential $domainCred -ErrorAction Stop
    Write-Host "  ✅ Joined domain $domainName" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️  Domain join failed. Will retry after reboot." -ForegroundColor Yellow
}

Write-Host "[4/6] Installing File Server role..." -ForegroundColor Yellow

Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools | Out-Null
Write-Host "  ✅ File Server role installed" -ForegroundColor Green

Write-Host "[5/6] Creating directory structure..." -ForegroundColor Yellow

$shareBase = "C:\Shares"
$directories = @(
    "HR",
    "IT",
    "Finance",
    "Public",
    "Sensitive",
    "Executives",
    "Departmental"
)

foreach ($dir in $directories) {
    $path = Join-Path $shareBase $dir
    New-Item -Path $path -ItemType Directory -Force | Out-Null
    Write-Host "      Created: $path" -ForegroundColor Green
}

Write-Host "[6/6] Creating sensitive files for attack scenarios..." -ForegroundColor Yellow

# HR files
@" 
EMPLOYEE SALARY DATA - CONFIDENTIAL
===================================
John Smith: $95,000
Jane Doe: $110,000
Bob Wilson: $145,000
Alice Johnson: $135,000
Charlie Brown: $85,000
Diana Prince: $250,000
Edward Nygma: $105,000
Bruce Wayne: $1,000,000

This file is for training purposes only.
DO NOT DISTRIBUTE
"@ | Out-File -FilePath "C:\Shares\HR\salaries_2026.xlsx" -Encoding utf8

# IT files
@"
DATABASE CONNECTIONS - PRODUCTION
=================================
DB_SERVER: dc01.lab.local
DB_NAME: corp_db
DB_USER: sa
DB_PASS: SqlAdmin123!
PORT: 1433

BACKUP SERVER: fileserver.lab.local\backup
BACKUP_USER: backup_admin  
BACKUP_PASS: Backup123!

SSH KEYS LOCATION: \\fileserver\IT\ssh_keys.zip
"@ | Out-File -FilePath "C:\Shares\IT\db_config.txt" -Encoding utf8

# Sensitive files (intentionally exposed)
@"
EXECUTIVE MEMO - PROJECT PHOENIX
================================
To: Bruce Wayne
From: Diana Prince
Date: March 1, 2026

The acquisition of Wayne Enterprises is proceeding as planned.
Final documents stored at: \\fileserver\Sensitive\merger.pdf

Meeting with investors: March 15, 10:00 AM
Location: Virtual (link sent separately)

This information must remain confidential until public announcement.
"@ | Out-File -FilePath "C:\Shares\Sensitive\executive_memo.txt" -Encoding utf8

# Create a fake password file
@"
PASSWORD REMINDER - DO NOT STORE HERE!
=======================================
WiFi: CorpNet / password: Welcome2026!
Admin portal: https://portal.lab.local / admin: P@ssw0rd
VPN: vpn.lab.local / user: bruce.wayne / pass: Batman!
"@ | Out-File -FilePath "C:\Shares\Public\passwords.txt" -Encoding utf8

# Create some financial documents
1..5 | ForEach-Object {
    "Quarterly Report Q$_ 2026 - Revenue: $([math]::Round((Get-Random -Minimum 1000000 -Maximum 5000000)))" | 
    Out-File -FilePath "C:\Shares\Finance\Q$_`_report.xlsx" -Encoding utf8
}

Write-Host "  ✅ Sensitive files created" -ForegroundColor Green

Write-Host "[7/6] Creating SMB shares..." -ForegroundColor Yellow

# HR Share - Properly restricted
New-SmbShare -Name "HR" -Path "C:\Shares\HR" `
    -Description "HR Department Files" `
    -ChangeAccess "LAB\HR_Users" `
    -FullAccess "LAB\Executives" `
    -ErrorAction SilentlyContinue
Write-Host "      Created share: HR (restricted to HR_Users)" -ForegroundColor Green

# IT Share - Properly restricted
New-SmbShare -Name "IT" -Path "C:\Shares\IT" `
    -Description "IT Department Files" `
    -ChangeAccess "LAB\IT_Users" `
    -FullAccess "LAB\Domain Admins" `
    -ErrorAction SilentlyContinue
Write-Host "      Created share: IT (restricted to IT_Users)" -ForegroundColor Green

# Finance Share
New-SmbShare -Name "Finance" -Path "C:\Shares\Finance" `
    -Description "Finance Department" `
    -ChangeAccess "LAB\Finance_Users" `
    -FullAccess "LAB\Executives" `
    -ErrorAction SilentlyContinue
Write-Host "      Created share: Finance" -ForegroundColor Green

# Public Share - Everyone can read (intentional)
New-SmbShare -Name "Public" -Path "C:\Shares\Public" `
    -Description "Public Files" `
    -ReadAccess "Everyone" `
    -ErrorAction SilentlyContinue
Write-Host "      Created share: Public (Everyone read - INTENTIONAL)" -ForegroundColor Yellow

# Sensitive Share - MISCONFIGURED: Everyone has read (vulnerability!)
New-SmbShare -Name "Sensitive" -Path "C:\Shares\Sensitive" `
    -Description "CONFIDENTIAL - MISCONFIGURED" `
    -ReadAccess "Everyone" `
    -ErrorAction SilentlyContinue
Write-Host "      Created share: Sensitive (Everyone read - INTENTIONAL VULNERABILITY!)" -ForegroundColor Red

# Executives Share
New-SmbShare -Name "Executives" -Path "C:\Shares\Executives" `
    -Description "Executive Only" `
    -FullAccess "LAB\Executives" `
    -ErrorAction SilentlyContinue
Write-Host "      Created share: Executives" -ForegroundColor Green

# Departmental Share
New-SmbShare -Name "Departmental" -Path "C:\Shares\Departmental" `
    -Description "Cross-departmental files" `
    -ChangeAccess "LAB\Domain Users" `
    -ErrorAction SilentlyContinue
Write-Host "      Created share: Departmental" -ForegroundColor Green

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "FILE SERVER SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "File Server IP: 192.168.1.20" -ForegroundColor White
Write-Host "Shares created:" -ForegroundColor White
Get-SmbShare | Where-Object {$_.Name -notin @('ADMIN$', 'C$', 'IPC$')} | 
    Format-Table Name, Path, Description -AutoSize

Write-Host ""
Write-Host "⚠️  INTENTIONAL VULNERABILITIES:" -ForegroundColor Red
Write-Host "  - 'Sensitive' share accessible to Everyone" -ForegroundColor Red
Write-Host "  - 'Public' share has passwords.txt file" -ForegroundColor Red
Write-Host "  - Database credentials stored in IT share" -ForegroundColor Red
Write-Host ""
Write-Host "System will reboot in 30 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
Restart-Computer -Force
