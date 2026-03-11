# App Server VM

This VM hosts the **crAPI** (Completely Ridiculous API) suite – a deliberately vulnerable API application. It consists of multiple microservices:

- API Gateway (port 80)
- Web UI (port 8080)
- Identity, Community, Workshop, Chatbot services
- PostgreSQL, MongoDB, MailHog (email capture on port 8025)

# Access the services:
-   crAPI API Gateway: http://<VM-IP>:80
-   crAPI Web UI: http://<VM-IP>:8080
-   MailHog UI: http://<VM-IP>:8025

# Network Configuration
-  This VM should be connected to the DMZ network (10.0.0.0/24) with static IP 10.0.0.20.
-  The firewall (pfSense) must allow inbound traffic to ports 80, 8080, and 8025 from the Isolated network (Kali) and optionally from the Internal network.

# Notes
-  View logs: docker logs <container_name>
-  The database credentials are set to simple values; change them in .env if needed.
-  MailHog captures emails sent by crAPI; view them at http://<VM-IP>:8025
