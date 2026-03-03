<#
.SYNOPSIS
    Configures a Windows Server as Domain Controller for lab.local domain
.DESCRIPTION
    This script installs AD DS, promotes server to domain controller,
    creates OUs, users, and security groups with intentional vulnerabilities
.NOTES
    Run as Administrator
    Version: 1.0
#>

#requires -RunAsAdministrator

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "DOMAIN CONTROLLER SETUP - lab.local" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration variables
$domainName = "lab.local"
$netbiosName = "LAB"
$safeModePassword = "P@ssw0rd123!" | ConvertTo-SecureString -AsPlainText -Force
$domainAdminPassword = "Admin123!" | ConvertTo-SecureString -AsPlainText -Force

# Network configuration
$ipAddress = "192.168.1.10"
$subnetMask = 24
$gateway = "192.168.1.1"
$dnsServers = @("127.0.0.1", "192.168.1.10")

Write-Host "[1/8] Configuring static IP address..." -ForegroundColor Yellow

# Get network adapter
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
if (-not $adapter) {
    Write-Host "ERROR: No active network adapter found!" -ForegroundColor Red
    exit 1
}

# Set static IP
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

Write-Host "[2/8] Renaming computer to DC01..." -ForegroundColor Yellow
Rename-Computer -NewName "DC01" -Force
Write-Host "  ✅ Computer renamed to DC01 (reboot pending)" -ForegroundColor Green

Write-Host "[3/8] Installing AD DS role..." -ForegroundColor Yellow
$adFeatures = @(
    "AD-Domain-Services",
    "DNS",
    "RSAT-AD-PowerShell",
    "RSAT-AD-AdminCenter",
    "RSAT-DNS-Server"
)

foreach ($feature in $adFeatures) {
    Install-WindowsFeature -Name $feature -IncludeManagementTools | Out-Null
}
Write-Host "  ✅ AD DS and DNS roles installed" -ForegroundColor Green

Write-Host "[4/8] Promoting to Domain Controller..." -ForegroundColor Yellow
Install-ADDSForest `
    -DomainName $domainName `
    -DomainNetbiosName $netbiosName `
    -SafeModeAdministratorPassword $safeModePassword `
    -InstallDNS `
    -Force `
    -NoRebootOnCompletion

Write-Host "  ✅ Domain controller promotion complete" -ForegroundColor Green

Write-Host "[5/8] Creating Organizational Units..." -ForegroundColor Yellow
Start-Sleep -Seconds 30  # Wait for AD to stabilize

$ous = @(
    "Employees",
    "Admins",
    "Computers",
    "Servers",
    "Groups",
    "ServiceAccounts"
)

foreach ($ou in $ous) {
    try {
        New-ADOrganizationalUnit -Name $ou -Path "DC=lab,DC=local" -ErrorAction Stop
        Write-Host "      Created OU: $ou" -ForegroundColor Green
    }
    catch {
        Write-Host "      OU $ou may already exist: $_" -ForegroundColor Yellow
    }
}

Write-Host "[6/8] Creating Security Groups..." -ForegroundColor Yellow

$groups = @(
    @{Name="HR_Users"; Description="Human Resources Department"},
    @{Name="IT_Users"; Description="Information Technology Department"},
    @{Name="Finance_Users"; Description="Finance Department"},
    @{Name="Executives"; Description="Executive Leadership"},
    @{Name="Domain_Admins"; Description="Domain Administrators (Restricted)"},
    @{Name="FileShare_HR"; Description="HR File Share Access"},
    @{Name="FileShare_IT"; Description="IT File Share Access"},
    @{Name="FileShare_Public"; Description="Public File Share Access"},
    @{Name="VPN_Users"; Description="VPN Access Users"}
)

foreach ($group in $groups) {
    try {
        New-ADGroup -Name $group.Name `
            -GroupScope Global `
            -GroupCategory Security `
            -Description $group.Description `
            -Path "OU=Groups,DC=lab,DC=local" `
            -ErrorAction Stop
        Write-Host "      Created group: $($group.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "      Group $($group.Name) may already exist: $_" -ForegroundColor Yellow
    }
}

Write-Host "[7/8] Creating Users (with weak passwords for training)..." -ForegroundColor Yellow

$users = @(
    @{Name="John Smith"; Sam="john.smith"; Dept="HR"; Groups=@("HR_Users", "FileShare_HR")},
    @{Name="Jane Doe"; Sam="jane.doe"; Dept="HR"; Groups=@("HR_Users", "FileShare_HR")},
    @{Name="Bob Wilson"; Sam="bob.wilson"; Dept="IT"; Groups=@("IT_Users", "FileShare_IT", "Domain_Admins")},
    @{Name="Alice Johnson"; Sam="alice.johnson"; Dept="IT"; Groups=@("IT_Users", "FileShare_IT")},
    @{Name="Charlie Brown"; Sam="charlie.brown"; Dept="Finance"; Groups=@("Finance_Users")},
    @{Name="Diana Prince"; Sam="diana.prince"; Dept="Executives"; Groups=@("Executives", "FileShare_HR", "FileShare_IT")},
    @{Name="Edward Nygma"; Sam="edward.nygma"; Dept="IT"; Groups=@("IT_Users")},  # Weak password - vulnerability!
    @{Name="Bruce Wayne"; Sam="bruce.wayne"; Dept="Executives"; Groups=@("Executives")}
)

foreach ($user in $users) {
    # Create password (intentionally weak for some users)
    if ($user.Sam -eq "edward.nygma") {
        $password = "password123" | ConvertTo-SecureString -AsPlainText -Force
    }
    elseif ($user.Sam -eq "bruce.wayne") {
        $password = "Batman!" | ConvertTo-SecureString -AsPlainText -Force
    }
    else {
        $password = "Password123!" | ConvertTo-SecureString -AsPlainText -Force
    }
    
    try {
        New-ADUser `
            -Name $user.Name `
            -GivenName ($user.Name.Split(' ')[0]) `
            -Surname ($user.Name.Split(' ')[1]) `
            -SamAccountName $user.Sam `
            -UserPrincipalName "$($user.Sam)@lab.local" `
            -EmailAddress "$($user.Sam)@lab.local" `
            -Department $user.Dept `
            -Path "OU=Employees,DC=lab,DC=local" `
            -AccountPassword $password `
            -Enabled $true `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires $true `
            -ErrorAction Stop
        
        # Add to groups
        foreach ($group in $user.Groups) {
            Add-ADGroupMember -Identity $group -Members $user.Sam -ErrorAction SilentlyContinue
        }
        Write-Host "      Created user: $($user.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "      Error creating user $($user.Name): $_" -ForegroundColor Red
    }
}

Write-Host "[8/8] Creating Service Accounts (intentional vulnerabilities)..." -ForegroundColor Yellow

# Service account with excessive privileges (vulnerability!)
$svcPassword = "SvcP@ss123" | ConvertTo-SecureString -AsPlainText -Force
try {
    New-ADUser `
        -Name "svc_backup" `
        -SamAccountName "svc_backup" `
        -UserPrincipalName "svc_backup@lab.local" `
        -Description "Backup service account - DO NOT USE - INTENTIONAL VULNERABILITY" `
        -Path "OU=ServiceAccounts,DC=lab,DC=local" `
        -AccountPassword $svcPassword `
        -Enabled $true `
        -PasswordNeverExpires $true `
        -ErrorAction Stop
    
    # Add to Domain Admins (bad practice - intentional)
    Add-ADGroupMember -Identity "Domain Admins" -Members "svc_backup"
    Write-Host "      Created service account: svc_backup (INTENTIONALLY IN DOMAIN ADMINS)" -ForegroundColor Yellow
}
catch {
    Write-Host "      Error creating service account: $_" -ForegroundColor Red
}

# Additional service account with weak password
$svc2Password = "backup123" | ConvertTo-SecureString -AsPlainText -Force
try {
    New-ADUser `
        -Name "svc_mssql" `
        -SamAccountName "svc_mssql" `
        -UserPrincipalName "svc_mssql@lab.local" `
        -Description "SQL Server service account" `
        -Path "OU=ServiceAccounts,DC=lab,DC=local" `
        -AccountPassword $svc2Password `
        -Enabled $true `
        -PasswordNeverExpires $true `
        -ErrorAction Stop
    
    Write-Host "      Created service account: svc_mssql" -ForegroundColor Green
}
catch {
    Write-Host "      Error creating service account: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "DOMAIN CONTROLLER SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Domain: lab.local" -ForegroundColor White
Write-Host "DC IP: 192.168.1.10" -ForegroundColor White
Write-Host "Safe Mode Password: P@ssw0rd123!" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  INTENTIONAL VULNERABILITIES:" -ForegroundColor Red
Write-Host "  - User 'edward.nygma' has weak password 'password123'" -ForegroundColor Red
Write-Host "  - Service account 'svc_backup' is in Domain Admins" -ForegroundColor Red
Write-Host "  - Password never expires for all users" -ForegroundColor Red
Write-Host ""
Write-Host "System will reboot in 60 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 60
Restart-Computer -Force
