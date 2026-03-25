# dc-setup-part2.ps1
# Runs automatically after reboot via scheduled task.
# Creates OUs, groups, users, and service accounts.
# Can also be run manually if scheduled task fails.

#requires -RunAsAdministrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Wait for AD web services to be fully ready
# AD DS starts after reboot but takes time to initialise
Write-Host "Waiting for AD services to initialise..." -ForegroundColor Yellow
$maxWait = 120
$waited  = 0
do {
    Start-Sleep -Seconds 10
    $waited += 10
    try {
        Get-ADDomain -ErrorAction Stop | Out-Null
        Write-Host "  OK: AD services ready after ${waited}s" -ForegroundColor Green
        break
    } catch {
        Write-Host "  Waiting... (${waited}s elapsed)" -ForegroundColor Gray
    }
} while ($waited -lt $maxWait)

if ($waited -ge $maxWait) {
    Write-Host "ERROR: AD services did not start within ${maxWait}s" -ForegroundColor Red
    Write-Host "       Wait a few minutes and run this script manually" -ForegroundColor Red
    exit 1
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "DC SETUP - PART 2 of 2" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# ── Step 1: Create Organisational Units ───────────────────────
Write-Host "[1/4] Creating Organisational Units..." -ForegroundColor Yellow

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
        New-ADOrganizationalUnit `
            -Name $ou `
            -Path "DC=lab,DC=local" `
            -ErrorAction Stop
        Write-Host "      Created OU: $ou" -ForegroundColor Green
    } catch {
        Write-Host "      OU $ou already exists - skipping" -ForegroundColor Gray
    }
}

# ── Step 2: Create Security Groups ────────────────────────────
Write-Host "[2/4] Creating Security Groups..." -ForegroundColor Yellow

$groups = @(
    @{Name="HR_Users";        Description="Human Resources Department"},
    @{Name="IT_Users";        Description="Information Technology Department"},
    @{Name="Finance_Users";   Description="Finance Department"},
    @{Name="Executives";      Description="Executive Leadership"},
    @{Name="Domain_Admins";   Description="Domain Administrators (Restricted)"},
    @{Name="FileShare_HR";    Description="HR File Share Access"},
    @{Name="FileShare_IT";    Description="IT File Share Access"},
    @{Name="FileShare_Public"; Description="Public File Share Access"},
    @{Name="VPN_Users";       Description="VPN Access Users"}
)

foreach ($group in $groups) {
    try {
        New-ADGroup `
            -Name $group.Name `
            -GroupScope Global `
            -GroupCategory Security `
            -Description $group.Description `
            -Path "OU=Groups,DC=lab,DC=local" `
            -ErrorAction Stop
        Write-Host "      Created group: $($group.Name)" -ForegroundColor Green
    } catch {
        Write-Host "      Group $($group.Name) already exists - skipping" -ForegroundColor Gray
    }
}

# ── Step 3: Create Users ───────────────────────────────────────
Write-Host "[3/4] Creating Users..." -ForegroundColor Yellow

$users = @(
    @{
        Name   = "John Smith"
        Sam    = "john.smith"
        Dept   = "HR"
        Pass   = "Password123!"
        Groups = @("HR_Users", "FileShare_HR", "FileShare_Public")
    },
    @{
        Name   = "Jane Doe"
        Sam    = "jane.doe"
        Dept   = "HR"
        Pass   = "Password123!"
        Groups = @("HR_Users", "FileShare_HR", "FileShare_Public")
    },
    @{
        # bob.wilson is a real domain admin — useful for lateral movement attacks
        Name   = "Bob Wilson"
        Sam    = "bob.wilson"
        Dept   = "IT"
        Pass   = "Password123!"
        Groups = @("IT_Users", "FileShare_IT", "FileShare_Public")
        DomainAdmin = $true
    },
    @{
        Name   = "Alice Johnson"
        Sam    = "alice.johnson"
        Dept   = "IT"
        Pass   = "Password123!"
        Groups = @("IT_Users", "FileShare_IT", "FileShare_Public")
    },
    @{
        Name   = "Charlie Brown"
        Sam    = "charlie.brown"
        Dept   = "Finance"
        Pass   = "Password123!"
        Groups = @("Finance_Users", "FileShare_Public")
    },
    @{
        Name   = "Diana Prince"
        Sam    = "diana.prince"
        Dept   = "Executives"
        Pass   = "Password123!"
        Groups = @("Executives", "FileShare_HR", "FileShare_IT", "FileShare_Public")
    },
    @{
        # Intentional vulnerability — weak password
        Name   = "Edward Nygma"
        Sam    = "edward.nygma"
        Dept   = "IT"
        Pass   = "password123"
        Groups = @("IT_Users", "FileShare_Public")
    },
    @{
        # Intentional vulnerability — guessable password
        Name   = "Bruce Wayne"
        Sam    = "bruce.wayne"
        Dept   = "Executives"
        Pass   = "Batman!"
        Groups = @("Executives", "FileShare_Public")
    }
)

foreach ($user in $users) {
    $securePass = $user.Pass | ConvertTo-SecureString -AsPlainText -Force
    try {
        New-ADUser `
            -Name              $user.Name `
            -GivenName         ($user.Name.Split(' ')[0]) `
            -Surname           ($user.Name.Split(' ')[1]) `
            -SamAccountName    $user.Sam `
            -UserPrincipalName "$($user.Sam)@lab.local" `
            -EmailAddress      "$($user.Sam)@lab.local" `
            -Department        $user.Dept `
            -Path              "OU=Employees,DC=lab,DC=local" `
            -AccountPassword   $securePass `
            -Enabled           $true `
            -ChangePasswordAtLogon $false `
            -PasswordNeverExpires  $true `
            -ErrorAction Stop

        foreach ($group in $user.Groups) {
            Add-ADGroupMember `
                -Identity $group `
                -Members  $user.Sam `
                -ErrorAction SilentlyContinue
        }

        # Add real Domain Admins membership where flagged
        if ($user.DomainAdmin) {
            Add-ADGroupMember `
                -Identity "Domain Admins" `
                -Members  $user.Sam `
                -ErrorAction SilentlyContinue
            Write-Host "      Created user: $($user.Name) [DOMAIN ADMIN]" -ForegroundColor Yellow
        } else {
            Write-Host "      Created user: $($user.Name)" -ForegroundColor Green
        }
    } catch {
        Write-Host "      ERROR creating $($user.Name): $_" -ForegroundColor Red
    }
}

# ── Step 4: Service Accounts ───────────────────────────────────
Write-Host "[4/4] Creating Service Accounts..." -ForegroundColor Yellow

# svc_backup — intentionally in Domain Admins (vulnerability)
$svcPass = "SvcP@ss123" | ConvertTo-SecureString -AsPlainText -Force
try {
    New-ADUser `
        -Name              "svc_backup" `
        -SamAccountName    "svc_backup" `
        -UserPrincipalName "svc_backup@lab.local" `
        -Description       "Backup service account - INTENTIONAL VULNERABILITY" `
        -Path              "OU=ServiceAccounts,DC=lab,DC=local" `
        -AccountPassword   $svcPass `
        -Enabled           $true `
        -PasswordNeverExpires $true `
        -ErrorAction Stop

    Add-ADGroupMember -Identity "Domain Admins" -Members "svc_backup"
    Write-Host "      Created: svc_backup [DOMAIN ADMIN - INTENTIONAL VULN]" -ForegroundColor Red
} catch {
    Write-Host "      ERROR creating svc_backup: $_" -ForegroundColor Red
}

# svc_mssql — weak password (vulnerability)
$svc2Pass = "backup123" | ConvertTo-SecureString -AsPlainText -Force
try {
    New-ADUser `
        -Name              "svc_mssql" `
        -SamAccountName    "svc_mssql" `
        -UserPrincipalName "svc_mssql@lab.local" `
        -Description       "SQL Server service account - weak password" `
        -Path              "OU=ServiceAccounts,DC=lab,DC=local" `
        -AccountPassword   $svc2Pass `
        -Enabled           $true `
        -PasswordNeverExpires $true `
        -ErrorAction Stop
    Write-Host "      Created: svc_mssql [WEAK PASSWORD - INTENTIONAL VULN]" -ForegroundColor Yellow
} catch {
    Write-Host "      ERROR creating svc_mssql: $_" -ForegroundColor Red
}

# Remove the scheduled task now that part 2 has run
Unregister-ScheduledTask -TaskName "DCSetupPart2" -Confirm:$false -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "DC SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Domain:              lab.local" -ForegroundColor White
Write-Host "DC IP:               192.168.1.10" -ForegroundColor White
Write-Host "Safe Mode Password:  P@ssw0rd123!" -ForegroundColor Yellow
Write-Host "Domain Join Cred:    LAB\Administrator / Admin123!" -ForegroundColor Yellow
Write-Host ""
Write-Host "INTENTIONAL VULNERABILITIES:" -ForegroundColor Red
Write-Host "  edward.nygma     password: password123 (weak)" -ForegroundColor Red
Write-Host "  bruce.wayne      password: Batman! (guessable)" -ForegroundColor Red
Write-Host "  svc_backup       in Domain Admins (privilege abuse)" -ForegroundColor Red
Write-Host "  svc_mssql        password: backup123 (weak)" -ForegroundColor Red
Write-Host "  bob.wilson       real Domain Admin (lateral movement target)" -ForegroundColor Red
Write-Host "  All users        PasswordNeverExpires = true" -ForegroundColor Red
Write-Host ""
Write-Host "DC setup fully complete. No reboot required." -ForegroundColor Green
