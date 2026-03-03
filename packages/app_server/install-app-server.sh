#!/bin/bash
# install-app-server.sh - Run on the App Server VM in cyber range

echo "=== Installing crAPI Microservices ==="

# Navigate to the directory with images (adjust path as needed)
cd /media/coordinator/app-server-package

# Step 1: Load all Docker images
echo "Loading crAPI Docker images..."
if [ -f docker-images/crapi-all-images.tar.gz ]; then
    gunzip -c docker-images/crapi-all-images.tar.gz | docker load
elif [ -f docker-images/crapi-all-images.tar ]; then
    docker load -i docker-images/crapi-all-images.tar
else
    echo "ERROR: Image file not found!"
    exit 1
fi

# Step 2: Verify images loaded
echo "Loaded images:"
docker images | grep -E "crapi|mailhog|mongo|postgres"

# Step 3: Copy docker-compose file
cp config-files/docker-compose-app.yml ./docker-compose.yml

# Step 4: Create necessary networks if not exist
docker network inspect crapi-network >/dev/null 2>&1 || docker network create crapi-network

# Step 5: Start all containers
echo "Starting crAPI services..."
docker-compose -f docker-compose.yml up -d

# Step 6: Wait for services to initialize
echo "Waiting for services to start (30 seconds)..."
sleep 30

# Step 7: Check status
echo "Container status:"
docker ps

# Step 8: Test endpoints
echo "Testing API Gateway (port 80)..."
curl -I http://localhost:80 2>/dev/null | head -n 1 || echo "Failed to connect to port 80"

echo "Testing MailHog (port 8025)..."
curl -I http://localhost:8025 2>/dev/null | head -n 1 || echo "Failed to connect to port 8025"

echo "=== Installation Complete ==="
echo "crAPI available at: http://[APP-VM-IP]:80"
echo "MailHog available at: http://[APP-VM-IP]:8025"
echo ""
echo "Default login: Create account at /identity/signup"
