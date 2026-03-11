# Web Server VM

This VM hosts two vulnerable web applications:
- **DVWA** (Damn Vulnerable Web Application) on port 8080
- **Juice Shop** (OWASP) on port 3001

Start the conatiners
- docker-compose -f docker-compose-web.yml up -d

Access the applications:
-   DVWA: http://<VM-IP>:8080
-   Juice Shop: http://<VM-IP>:3001

Network Configuration
-   This VM should be connected to the DMZ network (10.0.0.0/24) with static IP 10.0.0.10.
-   The firewall (pfSense) must allow inbound traffic to ports 8080 and 3001 from the
    Isolated attacker network (Kali) and optionally from the Internal network.

Logs
- docker logs dvwa
- docker logs juice-shop

Notes
-   DVWA requires initial setup: visit the setup page (/setup.php) and click "Create/Reset Database".
-   Juice Shop is ready out‑of‑the‑box.
