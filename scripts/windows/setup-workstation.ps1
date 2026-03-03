<#
.SYNOPSIS
    Configures Windows 10/11 workstation and joins to domain
.DESCRIPTION
    Sets static IP, joins domain, configures for user simulation
.NOTES
    Run as Administrator
    Version: 1.0
#>

#requires -RunAsAdministrator

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "WORKSTATION SETUP" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration variables
$ipAddress = "192.168.1.100"
$subnetMask = 24
$gateway = "192.168.1.1"
$dnsServers = @("192.168.1.10")
$domainName = "lab.local"
$computerName = "WS01"

Write-Host "[1/5] Configuring static IP address..." -ForegroundColor Yellow

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

# Test DNS resolution
Write-Host "[2/5] Testing DNS resolution..." -ForegroundColor Yellow
try {
    Resolve-DnsName -Name "dc01.lab.local" -ErrorAction Stop | Out-Null
    Write-Host "  ✅ DNS resolution working" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️  DNS resolution failed. Check DC is running." -ForegroundColor Yellow
}

Write-Host "[3/5] Renaming computer to $computerName..." -ForegroundColor Yellow
Rename-Computer -NewName $computerName -Force
Write-Host "  ✅ Computer renamed to $computerName" -ForegroundColor Green

Write-Host "[4/5] Joining domain $domainName..." -ForegroundColor Yellow

$domainCred = New-Object System.Management.Automation.PSCredential(
    "LAB\Administrator", 
    (ConvertTo-SecureString "Admin123!" -AsPlainText -Force)
)

try {
    Add-Computer -DomainName $domainName -Credential $domainCred -Restart -Force
    Write-Host "  ✅ Domain join initiated. System will restart." -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️  Domain join failed. Check:" -ForegroundColor Red
    Write-Host "     - DC is running (192.168.1.10)" -ForegroundColor Red
    Write-Host "     - DNS points to DC" -ForegroundColor Red
    Write-Host "     - Domain credentials correct" -ForegroundColor Red
    
    # Fallback - join after reboot
    Write-Host "  Attempting to join after reboot..." -ForegroundColor Yellow
    
    # Create scheduled task to join domain after reboot
    $scriptPath = "C:\Windows\Temp\JoinDomain.ps1"
    @"
    `$domainCred = New-Object System.Management.Automation.PSCredential(
        "LAB\Administrator", 
        (ConvertTo-SecureString "Admin123!" -AsPlainText -Force)
    )
    Add-Computer -DomainName "$domainName" -Credential `$domainCred -Force
    Restart-Computer -Force
"@ | Out-File -FilePath $scriptPath -Encoding utf8

    # Create scheduled task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
    Register-ScheduledTask -TaskName "JoinDomainAfterReboot" -Action $action -Trigger $trigger -Principal $principal -Force
    
    Write-Host "  Created scheduled task to join domain after reboot" -ForegroundColor Yellow
}

Write-Host "[5/5] Configuring local settings..." -ForegroundColor Yellow

# Disable Windows Firewall for testing (re-enable later)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Write-Host "  ✅ Windows Firewall disabled (for testing)" -ForegroundColor Yellow

# Enable RDP
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Host "  ✅ RDP enabled" -ForegroundColor Green

# Set power scheme to high performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
Write-Host "  ✅ Power scheme set to High Performance" -ForegroundColor Green

# Create test user data
New-Item -Path "C:\Users\Public\Desktop\README.txt" -ItemType File -Force -Value @"
WORKSTATION SETUP COMPLETE
==========================
IP Address: 192.168.1.100
Domain: lab.local

To verify domain join:
1. Open System Properties
2. Check "Full computer name" shows WS01.lab.local

To login with domain user:
Username: lab\[username]
Password: Password123! (or password123 for edward.nygma)

Sample users:
- john.smith / Password123!
- jane.doe / Password123!
- edward.nygma / password123 (WEAK - for training)
- bob.wilson / Password123!

To access file server:
\\fileserver.lab.local\Public
\\fileserver.lab.local\HR (if HR user)
\\fileserver.lab.local\IT (if IT user)

NOTES:
- This is a training environment
- Contains intentional vulnerabilities
- All activity is monitored by SIEM
"@

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "WORKSTATION SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Workstation IP: 192.168.1.100" -ForegroundColor White
Write-Host "Computer Name: WS01" -ForegroundColor White
Write-Host "Domain: lab.local" -ForegroundColor White
Write-Host ""
Write-Host "After reboot, login with:" -ForegroundColor Green
Write-Host "  Local Admin: .\Administrator (password from installation)" -ForegroundColor Green
Write-Host "  Domain User: lab\[username] / Password123!" -ForegroundColor Green
Write-Host ""
Write-Host "System will restart in 30 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
Restart-Computer -Force
