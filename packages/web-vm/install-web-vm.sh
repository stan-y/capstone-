#!/bin/bash
# install-web-vm.sh - Run on the Web VM in cyber range

echo "=== Installing Web VM Docker Environment ==="

# Load Docker images
echo "Loading DVWA image..."
docker load -i /media/coordinator/dvwa-image.tar

echo "Loading Juice Shop image..."
docker load -i /media/coordinator/juice-shop-image.tar

# Verify images loaded
echo "Loaded images:"
docker images | grep -E "dvwa|juice-shop"

# Copy docker-compose file
cp /media/coordinator/docker-compose-web.yml ./docker-compose.yml

# Start containers
echo "Starting containers..."
docker-compose up -d

# Check status
echo "Container status:"
docker ps

# Test endpoints
echo "Testing endpoints..."
curl -I http://localhost:8080 2>/dev/null | head -n 1
curl -I http://localhost:3001 2>/dev/null | head -n 1

echo "=== Installation Complete ==="
echo "DVWA available at: http://[WEB-VM-IP]:8080"
echo "Juice Shop available at: http://[WEB-VM-IP]:3001"
