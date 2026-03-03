# Static IP Configuration

## AI-Powered Attack Path Prediction System

---

# IP Address Assignment Table

## Network Overview

| Network | Subnet | Gateway (pfSense) | VLAN | Purpose |
|---------|--------|-------------------|------|---------|
| **DMZ** | 10.0.0.0/24 | 10.0.0.1 | 10 | Public-facing services |
| **Internal** | 192.168.1.0/24 | 192.168.1.1 | 20 | Corporate network |
| **Isolated** | 10.0.1.0/24 | 10.0.1.1 | 30 | Attacker network |
| **Management** | 192.168.10.0/24 | 192.168.10.1 | 99 | Admin & monitoring |
| **WAN** | DHCP from host | N/A | N/A | Internet access |

---

## pfSense Firewall Interfaces

| Interface | Network | IP Address | Subnet Mask | Description |
|-----------|---------|------------|-------------|-------------|
| **vtnet0 (WAN)** | WAN | DHCP | N/A | Internet connection |
| **vtnet1 (DMZ)** | DMZ | 10.0.0.1 | 255.255.255.0 | DMZ gateway |
| **vtnet2 (Internal)** | Internal | 192.168.1.1 | 255.255.255.0 | Internal gateway |
| **vtnet3 (Isolated)** | Isolated | 10.0.1.1 | 255.255.255.0 | Isolated gateway |
| **vtnet4 (Management)** | Management | 192.168.10.1 | 255.255.255.0 | Management gateway |

---

## DMZ Network (10.0.0.0/24)

| Hostname | Role | IP Address | MAC Address (if known) | DNS Servers | Default Gateway |
|----------|------|------------|------------------------|-------------|-----------------|
| **pfsense-dmz** | DMZ Gateway | 10.0.0.1 | N/A | 192.168.1.10 (DC) | N/A |
| **web-server** | Web Server VM | 10.0.0.10 | | 192.168.1.10 | 10.0.0.1 |
| **app-server** | App Server VM | 10.0.0.20 | | 192.168.1.10 | 10.0.0.1 |
| **reserved-1** | Future use | 10.0.0.30-10.0.0.49 | | | |
| **reserved-dhcp** | DHCP pool (if enabled) | 10.0.0.50-10.0.0.254 | | | |

### DMZ Services & Ports

| VM | Service | Port | Protocol | URL/Connection String |
|----|---------|------|----------|----------------------|
| **web-server** | DVWA | 8080 | TCP | `http://10.0.0.10:8080` |
| **web-server** | Juice Shop | 3001 | TCP | `http://10.0.0.10:3001` |
| **web-server** | SSH | 22 | TCP | `ssh user@10.0.0.10` |
| **app-server** | crAPI API Gateway | 80 | TCP | `http://10.0.0.20` |
| **app-server** | crAPI Web UI | 8080 | TCP | `http://10.0.0.20:8080` |
| **app-server** | MailHog UI | 8025 | TCP | `http://10.0.0.20:8025` |
| **app-server** | MailHog SMTP | 1025 | TCP | SMTP relay |
| **app-server** | SSH | 22 | TCP | `ssh user@10.0.0.20` |

---

## Internal Network (192.168.1.0/24)

| Hostname | Role | IP Address | MAC Address (if known) | DNS Servers | Default Gateway |
|----------|------|------------|------------------------|-------------|-----------------|
| **pfsense-int** | Internal Gateway | 192.168.1.1 | N/A | 192.168.1.10 | N/A |
| **dc01** | Domain Controller | 192.168.1.10 | | 127.0.0.1, 192.168.1.10 | 192.168.1.1 |
| **fileserver** | File Server | 192.168.1.20 | | 192.168.1.10 | 192.168.1.1 |
| **ws01** | Workstation | 192.168.1.100 | | 192.168.1.10 | 192.168.1.1 |
| **reserved-servers** | Future servers | 192.168.1.30-192.168.1.99 | | | |
| **reserved-dhcp** | DHCP pool | 192.168.1.101-192.168.1.254 | | | |

### Internal Services & Ports

| VM | Service | Port | Protocol | Notes |
|----|---------|------|----------|-------|
| **dc01** | Active Directory | 389 | TCP/UDP | LDAP |
| **dc01** | Kerberos | 88 | TCP/UDP | Authentication |
| **dc01** | DNS | 53 | TCP/UDP | Name resolution |
| **dc01** | SMB | 445 | TCP | File sharing |
| **dc01** | RDP | 3389 | TCP | Remote admin |
| **fileserver** | SMB | 445 | TCP | File shares |
| **fileserver** | RDP | 3389 | TCP | Remote admin |
| **ws01** | RDP | 3389 | TCP | Remote access |

---

## Isolated Network (10.0.1.0/24)

| Hostname | Role | IP Address | MAC Address (if known) | DNS Servers | Default Gateway |
|----------|------|------------|------------------------|-------------|-----------------|
| **pfsense-iso** | Isolated Gateway | 10.0.1.1 | N/A | 192.168.1.10 (if needed) | N/A |
| **kali-attacker** | Kali Linux | 10.0.1.100 | | None (or 192.168.1.10) | 10.0.1.1 |
| **reserved-attackers** | Future attackers | 10.0.1.101-10.0.1.254 | | | |

### Isolated Network Notes

- **NO DIRECT INTERNET ACCESS** - All traffic must go through pfSense
- **DNS:** Optional - can use DC at 192.168.1.10 if needed
- **Purpose:** Simulate external attacker with no visibility into internal networks

---

## Management Network (192.168.10.0/24)

| Hostname | Role | IP Address | MAC Address (if known) | DNS Servers | Default Gateway |
|----------|------|------------|------------------------|-------------|-----------------|
| **pfsense-mgmt** | Management Gateway | 192.168.10.1 | N/A | 192.168.1.10 | N/A |
| **jump-box** | Jump Box | 192.168.10.10 | | 192.168.1.10 | 192.168.10.1 |
| **siem** | SIEM VM | 192.168.10.20 | | 192.168.1.10 | 192.168.10.1 |
| **reserved-mgmt** | Future mgmt VMs | 192.168.10.30-192.168.10.254 | | | |

### Management Services & Ports

| VM | Service | Port | Protocol | Access |
|----|---------|------|----------|--------|
| **jump-box** | SSH | 22 | TCP | `ssh admin@192.168.10.10` |
| **jump-box** | RDP gateway | 3389 | TCP | RDP through jump box |
| **siem** | SSH | 22 | TCP | `ssh user@192.168.10.20` |
| **siem** | Backend API | 8000 | TCP | `http://192.168.10.20:8000/docs` |
| **siem** | LSTM API | 8001 | TCP | `http://192.168.10.20:8001` |
| **siem** | Dashboard | 8501 | TCP | `http://192.168.10.20:8501` |
| **siem** | Zeek logs | various | TCP/UDP | Log aggregation |

---

## SIEM VM - Multiple NICs (Critical!)

The SIEM VM has **4 network interfaces** - one on each network for monitoring.

| Interface | Network | IP Address | Promiscuous Mode | Purpose |
|-----------|---------|------------|------------------|---------|
| **eth0** | Management | 192.168.10.20/24 | ❌ No | Admin access, API endpoints |
| **eth1** | DMZ | 10.0.0.20/24? (or no IP) | ✅ **YES** | Monitor DMZ traffic |
| **eth2** | Internal | 192.168.1.20/24? (or no IP) | ✅ **YES** | Monitor Internal traffic |
| **eth3** | Isolated | 10.0.1.20/24? (or no IP) | ✅ **YES** | Monitor attacker traffic |

**Note:** The monitoring interfaces (eth1, eth2, eth3) can either:
- Have no IP address (pure monitoring)
- Have an IP for management/debugging

**Recommended:** No IP on monitoring NICs to prevent them from becoming attack targets.

---

## DNS Configuration

### Primary DNS: Domain Controller (192.168.1.10)

Add these DNS records to your Active Directory DNS:

| Hostname | FQDN | IP Address | Type |
|----------|------|------------|------|
| **pfsense** | pfsense.lab.local | 192.168.1.1 | A |
| **pfsense-dmz** | pfsense-dmz.lab.local | 10.0.0.1 | A |
| **pfsense-int** | pfsense-int.lab.local | 192.168.1.1 | A |
| **pfsense-iso** | pfsense-iso.lab.local | 10.0.1.1 | A |
| **pfsense-mgmt** | pfsense-mgmt.lab.local | 192.168.10.1 | A |
| **web-server** | web.lab.local | 10.0.0.10 | A |
| **app-server** | app.lab.local | 10.0.0.20 | A |
| **dc01** | dc01.lab.local | 192.168.1.10 | A |
| **fileserver** | fileserver.lab.local | 192.168.1.20 | A |
| **ws01** | ws01.lab.local | 192.168.1.100 | A |
| **kali** | kali.lab.local | 10.0.1.100 | A |
| **jump-box** | jump.lab.local | 192.168.10.10 | A |
| **siem** | siem.lab.local | 192.168.10.20 | A |

### /etc/hosts File (Alternative for Linux VMs)

If DNS is not available, add this to `/etc/hosts` on all Linux VMs:

```
# DMZ Network
10.0.0.1    pfsense-dmz.lab.local pfsense-dmz
10.0.0.10   web.lab.local web web-server
10.0.0.20   app.lab.local app app-server

# Internal Network
192.168.1.1 pfsense-int.lab.local pfsense-int
192.168.1.10 dc01.lab.local dc01 dc
192.168.1.20 fileserver.lab.local fileserver fs
192.168.1.100 ws01.lab.local ws01 workstation

# Isolated Network
10.0.1.1    pfsense-iso.lab.local pfsense-iso
10.0.1.100  kali.lab.local kali attacker

# Management Network
192.168.10.1    pfsense-mgmt.lab.local pfsense-mgmt
192.168.10.10   jump.lab.local jump jump-box
192.168.10.20   siem.lab.local siem
```

---

## DHCP Configuration (Optional)

### Internal Network DHCP Pool (if enabled on DC)

| Setting | Value |
|---------|-------|
| **Scope** | 192.168.1.101 - 192.168.1.200 |
| **Subnet Mask** | 255.255.255.0 |
| **Default Gateway** | 192.168.1.1 |
| **DNS Servers** | 192.168.1.10 |
| **Domain** | lab.local |
| **Lease Duration** | 8 hours |

### DMZ Network - **NO DHCP** (Static only)
### Isolated Network - **NO DHCP** (Static only)
### Management Network - **NO DHCP** (Static only)

---

## VLAN Configuration (if using VLANs)

| Network | VLAN ID | Parent Interface | Subnet |
|---------|---------|------------------|--------|
| **DMZ** | 10 | vtnet1 | 10.0.0.0/24 |
| **Internal** | 20 | vtnet2 | 192.168.1.0/24 |
| **Isolated** | 30 | vtnet3 | 10.0.1.0/24 |
| **Management** | 99 | vtnet4 | 192.168.10.0/24 |

---

## Quick Reference Card

```bash
# Quick SSH/RDP connections
ssh user@10.0.0.10    # Web Server
ssh user@10.0.0.20    # App Server
ssh user@192.168.1.10 # DC (if SSH enabled)
ssh user@10.0.1.100   # Kali
ssh admin@192.168.10.10 # Jump Box
ssh user@192.168.10.20 # SIEM

# RDP to Windows
rdesktop 192.168.1.10   # DC
rdesktop 192.168.1.20   # File Server
rdesktop 192.168.1.100  # Workstation

# Web UIs
http://10.0.0.10:8080   # DVWA
http://10.0.0.10:3001   # Juice Shop
http://10.0.0.20:80     # crAPI API
http://10.0.0.20:8080   # crAPI Web
http://10.0.0.20:8025   # MailHog
http://192.168.10.20:8501 # SIEM Dashboard
http://192.168.10.1     # pfSense Web GUI
```

---

## Validation Commands

```bash
# From Jump Box, test all connections
ping 10.0.0.10
ping 10.0.0.20
ping 192.168.1.10
ping 192.168.1.20
ping 192.168.1.100
ping 10.0.1.100
ping 192.168.10.20

# From SIEM, verify promiscuous mode
sudo tcpdump -i eth1 -c 10  # Should see DMZ traffic
sudo tcpdump -i eth2 -c 10  # Should see Internal traffic
sudo tcpdump -i eth3 -c 10  # Should see Isolated traffic
```

---

## Last Updated
**March 3 2026**
