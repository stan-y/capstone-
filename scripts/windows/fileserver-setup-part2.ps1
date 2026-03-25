# fileserver-setup-part2.ps1
# Runs automatically after reboot via scheduled task.
# Creates SMB shares with domain group permissions.
# Requires DC to be running and domain join to be complete.

#requires -RunAsAdministrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "FILE SERVER SETUP - PART 2 of 2" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Wait for SMB service to be ready
Write-Host "Waiting for Server service to start..." -ForegroundColor Yellow
$waited = 0
do {
    Start-Sleep -Seconds 5
    $waited += 5
    $svc = Get-Service -Name "LanmanServer" -ErrorAction SilentlyContinue
} while ($svc.Status -ne "Running" -and $waited -lt 60)

if ($svc.Status -ne "Running") {
    Write-Host "ERROR: LanmanServer service not running after 60s" -ForegroundColor Red
    exit 1
}
Write-Host "  OK: Server service running" -ForegroundColor Green

# ── Create SMB Shares ──────────────────────────────────────────
# All shares reference domain groups — DC must be reachable
# Domain join must be complete (done in Part 1 before reboot)
Write-Host "[1/1] Creating SMB shares..." -ForegroundColor Yellow

# HR — restricted to HR users and Executives
New-SmbShare `
    -Name         "HR" `
    -Path         "C:\Shares\HR" `
    -Description  "HR Department Files - Restricted" `
    -ChangeAccess "LAB\HR_Users" `
    -FullAccess   "LAB\Executives" `
    -ErrorAction SilentlyContinue
Write-Host "      Created: HR (LAB\HR_Users + LAB\Executives)" -ForegroundColor Green

# IT — restricted to IT users and Domain Admins
New-SmbShare `
    -Name         "IT" `
    -Path         "C:\Shares\IT" `
    -Description  "IT Department Files - Restricted" `
    -ChangeAccess "LAB\IT_Users" `
    -FullAccess   "LAB\Domain Admins" `
    -ErrorAction SilentlyContinue
Write-Host "      Created: IT (LAB\IT_Users + LAB\Domain Admins)" -ForegroundColor Green

# Finance — restricted to Finance and Executives
New-SmbShare `
    -Name         "Finance" `
    -Path         "C:\Shares\Finance" `
    -Description  "Finance Department Files" `
    -ChangeAccess "LAB\Finance_Users" `
    -FullAccess   "LAB\Executives" `
    -ErrorAction SilentlyContinue
Write-Host "      Created: Finance (LAB\Finance_Users)" -ForegroundColor Green

# Public — Everyone can read (intentional — contains passwords.txt)
New-SmbShare `
    -Name        "Public" `
    -Path        "C:\Shares\Public" `
    -Description "Public Files - Everyone Read" `
    -ReadAccess  "Everyone" `
    -ErrorAction SilentlyContinue
Write-Host "      Created: Public (Everyone read - INTENTIONAL)" -ForegroundColor Yellow

# Sensitive — Everyone read (intentional vulnerability)
New-SmbShare `
    -Name        "Sensitive" `
    -Path        "C:\Shares\Sensitive" `
    -Description "CONFIDENTIAL - INTENTIONALLY MISCONFIGURED" `
    -ReadAccess  "Everyone" `
    -ErrorAction SilentlyContinue
Write-Host "      Created: Sensitive (Everyone read - INTENTIONAL VULN)" -ForegroundColor Red

# Executives — Executives only
New-SmbShare `
    -Name        "Executives" `
    -Path        "C:\Shares\Executives" `
    -Description "Executive Files - Restricted" `
    -FullAccess  "LAB\Executives" `
    -ErrorAction SilentlyContinue
Write-Host "      Created: Executives (LAB\Executives only)" -ForegroundColor Green

# Departmental — all domain users
New-SmbShare `
    -Name         "Departmental" `
    -Path         "C:\Shares\Departmental" `
    -Description  "Cross-departmental Files" `
    -ChangeAccess "LAB\Domain Users" `
    -ErrorAction SilentlyContinue
Write-Host "      Created: Departmental (LAB\Domain Users)" -ForegroundColor Green

# Enable SMBv1 — intentional vulnerability for lateral movement attacks
Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force
Write-Host "      Enabled SMBv1 (INTENTIONAL VULNERABILITY)" -ForegroundColor Red

# Disable SMB signing — allows man-in-the-middle (vulnerability)
Set-SmbServerConfiguration -RequireSecuritySignature $false -Force
Write-Host "      Disabled SMB signing (INTENTIONAL VULNERABILITY)" -ForegroundColor Red

# Remove the scheduled task
Unregister-ScheduledTask `
    -TaskName "FileServerSetupPart2" `
    -Confirm:$false `
    -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "FILE SERVER SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "File Server IP: 192.168.1.20" -ForegroundColor White
Write-Host ""
Write-Host "Shares created:" -ForegroundColor White
Get-SmbShare | Where-Object {$_.Name -notin @('ADMIN$','C$','IPC$')} |
    Format-Table Name, Path, Description -AutoSize

Write-Host ""
Write-Host "INTENTIONAL VULNERABILITIES:" -ForegroundColor Red
Write-Host "  Sensitive share  accessible to Everyone" -ForegroundColor Red
Write-Host "  Public share     contains passwords.txt" -ForegroundColor Red
Write-Host "  IT share         contains database credentials" -ForegroundColor Red
Write-Host "  SMBv1            enabled" -ForegroundColor Red
Write-Host "  SMB signing      disabled" -ForegroundColor Red
Write-Host ""
Write-Host "File Server setup fully complete." -ForegroundColor Green
