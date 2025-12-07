#!/bin/bash

echo "=== Detecting OS ==="
OS_ID=$(grep '^ID=' /etc/os-release | cut -d'=' -f2)
OS_VER=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
echo "OS: $OS_ID $OS_VER"

echo "=== Installing Docker using official get.docker.com script ==="
curl -fsSL https://get.docker.com -o get-docker.sh
chmod +x get-docker.sh

sh get-docker.sh
if [ $? -ne 0 ]; then
    echo "Docker install failed using default. Retrying with debian repo method..."
    curl -fsSL https://download.docker.com/linux/debian/gpg -o docker.gpg
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo mv docker.gpg /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

echo "=== Starting Docker Daemon ==="

# Bitnami không có systemd
if command -v systemctl &> /dev/null; then
    echo "System has systemd. Trying systemctl..."
    sudo systemctl start docker 2>/dev/null
    sudo systemctl enable docker 2>/dev/null
fi

# Kiểm tra docker daemon đã chạy chưa
if ! sudo docker info >/dev/null 2>&1; then
    echo "Docker daemon not running. Starting manually..."
    sudo nohup dockerd > /var/log/dockerd.log 2>&1 &
    sleep 5
fi

if ! sudo docker info >/dev/null 2>&1; then
    echo "   Docker is still not running. Start it manually with:"
    echo "   sudo dockerd &"
    exit 1
fi

echo "Docker is running OK."

# Docker compose
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "Installing docker-compose standalone..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo "=== Docker & Docker Compose Ready ==="

# Environment setup
if [ ! -f .env ]; then
    cp .env.example .env
fi

echo "=== Starting Docker Compose containers ==="
sudo docker compose pull
sudo docker compose up -d

echo "=== All done ==="
