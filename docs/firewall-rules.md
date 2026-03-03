pfSense Firewall Configuration

## AI-Powered Attack Path Prediction System

---

# Firewall Rules Matrix

## Overview

This document defines all pfSense firewall rules for the segmented network architecture. The firewall uses a **default deny** policy - all traffic is blocked unless explicitly allowed.

---

## Network Zones Summary

| Zone | Interface | Subnet | pfSense IP | VLAN (if applicable) |
|------|-----------|--------|------------|---------------------|
| **WAN** | vtnet0 | DHCP from host | DHCP | N/A |
| **DMZ** | vtnet1 | 10.0.0.0/24 | 10.0.0.1 | 10 |
| **Internal** | vtnet2 | 192.168.1.0/24 | 192.168.1.1 | 20 |
| **Isolated** | vtnet3 | 10.0.1.0/24 | 10.0.1.1 | 30 |
| **Management** | vtnet4 | 192.168.10.0/24 | 192.168.10.1 | 99 |

---

## Floating Rules (Applied to All Interfaces)

These rules are processed before interface-specific rules.

| # | Action | Protocol | Source | Destination | Description |
|---|--------|----------|--------|-------------|-------------|
| F1 | Pass | ICMP | any | any | Allow ping for troubleshooting (disable after testing) |
| F2 | Block | IP | any | 224.0.0.0/4 | Block multicast |
| F3 | Block | IP | any | 255.255.255.255 | Block broadcast |

---

## WAN Interface Rules (vtnet0)

*Default: Block all incoming, allow all outgoing*

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| W1 | Pass | TCP | any | DMZ Network | 80,443 | HTTP/HTTPS to Web Server |
| W2 | Pass | TCP | any | App Server (10.0.0.20) | 80 | API access from internet |
| W3 | Pass | TCP | any | App Server (10.0.0.20) | 8080 | crAPI web interface |
| W4 | Pass | TCP | any | Web Server (10.0.0.10) | 8080 | DVWA access |
| W5 | Pass | TCP | any | Web Server (10.0.0.10) | 3001 | Juice Shop access |
| W6 | Block | IP | any | any | any | Block all other inbound |

---

## DMZ Interface Rules (vtnet1)

### Inbound Rules (Traffic FROM DMZ)

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| D1 | Pass | TCP | DMZ Net | Internal Net | 3306 | App Server → Database (if DB in Internal) |
| D2 | Pass | TCP | DMZ Net | Management Net | 123 | NTP for time sync |
| D3 | Pass | UDP | DMZ Net | Management Net | 53 | DNS queries |
| D4 | Pass | TCP | DMZ Net | any | 80,443 | Web access for updates (if enabled) |
| D5 | Block | IP | DMZ Net | Internal Net | any | Block all other DMZ→Internal |
| D6 | Block | IP | DMZ Net | Isolated Net | any | DMZ should not initiate to Isolated |

### Outbound Rules (Traffic TO DMZ)

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| D7 | Pass | TCP | Internal Net | DMZ Net | 80,443,8080,3001 | Internal users accessing web apps |
| D8 | Pass | TCP | Isolated Net | DMZ Net | 80,443,8080,3001 | Kali attacks on web apps |
| D9 | Pass | TCP | Management Net | DMZ Net | 22 | SSH from Jump Box to DMZ VMs |
| D10 | Pass | TCP | Management Net | DMZ Net | 8000,8001,8501 | SIEM monitoring access |

---

## Internal Interface Rules (vtnet2)

### Inbound Rules (Traffic FROM Internal)

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| I1 | Pass | TCP/UDP | Internal Net | any | 53 | DNS queries to external |
| I2 | Pass | TCP | Internal Net | any | 80,443 | Web browsing |
| I3 | Pass | TCP | Internal Net | DMZ Net | 80,443,8080,3001 | Access web apps |
| I4 | Pass | TCP | Internal Net | Management Net | 22 | SSH to Jump Box |
| I5 | Pass | TCP | Internal Net | Management Net | 3389 | RDP to Jump Box (if needed) |
| I6 | Pass | TCP | Workstation (192.168.1.100) | DC (192.168.1.10) | 88,389,445 | Kerberos, LDAP, SMB |
| I7 | Pass | TCP | Workstation (192.168.1.100) | File Server (192.168.1.20) | 445 | SMB file access |

### Outbound Rules (Traffic TO Internal)

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| I8 | Pass | TCP | Management Net | Internal Net | 22,3389 | SSH/RDP from Jump Box |
| I9 | Pass | IP | SIEM (192.168.10.20) | Internal Net | any | Monitoring (promiscuous mode) |
| I10 | Pass | TCP | Isolated Net | Internal Net | 445,3389 | Kali lateral movement attempts |
| I11 | Pass | TCP | Isolated Net | DC (192.168.1.10) | 88,389 | Kerberos attacks |
| I12 | Block | IP | DMZ Net | Internal Net | any | Block DMZ→Internal (except D1) |

---

## Isolated Interface Rules (vtnet3)

### Design Philosophy: **Attacker Freedom with Monitoring**

The Isolated zone is where Kali lives. We want attackers to have freedom to attack, but everything is monitored.

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| X1 | Pass | TCP/UDP | Isolated Net | DMZ Net | any | Allow all attacks on DMZ |
| X2 | Pass | TCP/UDP | Isolated Net | Internal Net | 445,3389,22,80,443,8080 | Allow lateral movement attempts |
| X3 | Pass | TCP | Isolated Net | DC (192.168.1.10) | 88,389,445 | Kerberos, LDAP, SMB attacks |
| X4 | Pass | TCP | Isolated Net | File Server (192.168.1.20) | 445 | SMB attacks |
| X5 | Pass | TCP | Isolated Net | Workstation (192.168.1.100) | 3389 | RDP attacks |
| X6 | Pass | ICMP | Isolated Net | any | any | Allow ping for recon |
| X7 | Block | IP | Isolated Net | any | any | Block access to internet |
| X8 | Block | IP | Isolated Net | Management Net | any | Block access to management (except SIEM) |
| X9 | Pass | IP | Isolated Net | SIEM (192.168.10.20) | any | SIEM monitoring (promiscuous) |

---

## Management Interface Rules (vtnet4)

### Inbound Rules (Traffic FROM Management)

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| M1 | Pass | TCP | Jump Box (192.168.10.10) | any | 22 | SSH from Jump Box to all VMs |
| M2 | Pass | TCP | Jump Box (192.168.10.10) | Internal Net | 3389 | RDP to Windows VMs |
| M3 | Pass | TCP | SIEM (192.168.10.20) | any | any | SIEM monitoring (promiscuous) |
| M4 | Pass | TCP | Management Net | pfSense (192.168.10.1) | 443 | Web GUI access |

### Outbound Rules (Traffic TO Management)

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| M5 | Pass | TCP | any | Management Net | 514 | Syslog from all VMs to SIEM |
| M6 | Pass | UDP | any | Management Net | 514 | Syslog from all VMs to SIEM |
| M7 | Pass | IP | DMZ Net | SIEM (192.168.10.20) | any | SIEM monitoring |
| M8 | Pass | IP | Internal Net | SIEM (192.168.10.20) | any | SIEM monitoring |
| M9 | Pass | IP | Isolated Net | SIEM (192.168.10.20) | any | SIEM monitoring |
| M10 | Block | IP | any | Management Net | 22 | Block direct SSH to management (use Jump Box) |

---

## NAT Rules

### Outbound NAT (Automatic)

| Interface | Source | Description |
|-----------|--------|-------------|
| WAN | DMZ Net | Allow DMZ to internet (if needed) |
| WAN | Internal Net | Allow Internal to internet |
| WAN | Management Net | Allow Management to internet |

### Port Forwarding (Inbound NAT)

| # | Protocol | Source | Source Port | Dest IP | Dest Port | Redirect IP | Redirect Port | Description |
|---|----------|--------|-------------|---------|-----------|-------------|---------------|-------------|
| N1 | TCP | any | any | WAN IP | 8080 | 10.0.0.10 | 8080 | DVWA external access |
| N2 | TCP | any | any | WAN IP | 3001 | 10.0.0.10 | 3001 | Juice Shop external access |
| N3 | TCP | any | any | WAN IP | 80 | 10.0.0.20 | 80 | crAPI API external access |
| N4 | TCP | any | any | WAN IP | 8080 | 10.0.0.20 | 8080 | crAPI Web external access |

---

## Aliases (For Easier Management)

### Host Aliases

| Name | IP Address | Description |
|------|------------|-------------|
| `WEB_VM` | 10.0.0.10 | Web Server |
| `APP_VM` | 10.0.0.20 | App Server |
| `DC_VM` | 192.168.1.10 | Domain Controller |
| `FILE_VM` | 192.168.1.20 | File Server |
| `WS_VM` | 192.168.1.100 | Workstation |
| `KALI_VM` | 10.0.1.100 | Kali Attacker |
| `JUMP_VM` | 192.168.10.10 | Jump Box |
| `SIEM_VM` | 192.168.10.20 | SIEM |

### Network Aliases

| Name | Subnet | Description |
|------|--------|-------------|
| `DMZ_NET` | 10.0.0.0/24 | DMZ network |
| `INT_NET` | 192.168.1.0/24 | Internal network |
| `ISO_NET` | 10.0.1.0/24 | Isolated network |
| `MGMT_NET` | 192.168.10.0/24 | Management network |

### Port Aliases

| Name | Ports | Description |
|------|-------|-------------|
| `WEB_PORTS` | 80,443,8080,3001 | Web application ports |
| `AD_PORTS` | 88,389,445,464,636 | Active Directory ports |
| `SMB_PORTS` | 445,139 | SMB/CIFS ports |
| `RDP_PORT` | 3389 | Remote Desktop |
| `SSH_PORT` | 22 | Secure Shell |

---

## Rule Order Summary (Critical!)

Rules are processed **top to bottom**. First match wins.

### WAN Interface Order
1. Pass web traffic to DMZ
2. Block everything else

### DMZ Interface Order
1. Allow established connections back in
2. Allow specific DMZ→Internal (database)
3. Block DMZ→Internal
4. Allow Internal→DMZ
5. Allow Isolated→DMZ (attacks)
6. Block everything else

### Internal Interface Order
1. Allow established connections
2. Allow Internal→Internet
3. Allow Internal→DMZ
4. Allow Management→Internal
5. Allow Isolated→Internal (monitored attacks)
6. Block DMZ→Internal
7. Block everything else

### Isolated Attacker Interface Order
1. Allow all attacks to DMZ
2. Allow all attacks to Internal
3. Block Internet
4. Block Management (except SIEM)
5. Allow all to SIEM (monitoring)

---

## Verification Commands

```bash
# On pfSense CLI
pfctl -sr              # Show rules
pfctl -sn              # Show NAT
pfctl -si              # Show statistics
tcpdump -i vtnet1      # Monitor DMZ interface
```

---

## Testing Matrix

| Test | Source | Destination | Expected | Command |
|------|--------|-------------|----------|---------|
| T1 | Kali (10.0.1.100) | Web (10.0.0.10:8080) | ✅ Allow | `curl http://10.0.0.10:8080` |
| T2 | Kali (10.0.1.100) | DC (192.168.1.10:445) | ✅ Allow | `nc -zv 192.168.1.10 445` |
| T3 | Kali (10.0.1.100) | Jump Box (192.168.10.10:22) | ❌ Block | `ssh 192.168.10.10` |
| T4 | Web (10.0.0.10) | DC (192.168.1.10:445) | ❌ Block | `nc -zv 192.168.1.10 445` |
| T5 | Internal Workstation | Internet | ✅ Allow | `ping 8.8.8.8` |
| T6 | Jump Box | DC (3389) | ✅ Allow | `rdesktop 192.168.1.10` |

---

## Last Updated
**March 2026**
