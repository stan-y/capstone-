# On all Ubuntu VMs
sudo apt update && sudo apt install -y \
    docker.io \
    docker-compose \
    python3-pip \
    git \
    curl \
    wget \
    net-tools \
    tcpdump

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker
