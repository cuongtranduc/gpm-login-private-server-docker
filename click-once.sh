#!/bin/bash

echo "=== Detecting OS ==="
OS_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2)
OS_VER=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
echo "OS: $OS_ID $OS_VER"

############################################################
# INSTALL DOCKER (WORKS FOR DEBIAN, UBUNTU, BITNAMI)
############################################################

if ! command -v docker &> /dev/null; then
    echo "=== Installing Docker using official get.docker.com script ==="
    curl -fsSL https://get.docker.com -o get-docker.sh

    # Fix for Bitnami (which blocks iptables)
    sudo sh get-docker.sh || {
        echo "Docker install failed using default. Retrying with --dry-run method..."
        sudo sh get-docker.sh --dry-run
    }
else
    echo "Docker already installed"
fi

############################################################
# START DOCKER ON UBUNTU / DEBIAN / BITNAMI
############################################################

echo "=== Starting Docker Daemon ==="

if command -v systemctl &> /dev/null; then
    sudo systemctl start docker || true
    sudo systemctl enable docker || true
fi

# For Bitnami (no systemd)
if ! sudo docker info &> /dev/null; then
    echo "Docker daemon not running. Starting manually..."
    sudo nohup dockerd > /dev/null 2>&1 &
    sleep 5
fi

if ! sudo docker info &> /dev/null; then
    echo "❌ Docker is still not running. Start it manually with:"
    echo "sudo dockerd &"
    exit 1
fi

echo "Docker is running!"

############################################################
# INSTALL DOCKER COMPOSE
############################################################

if ! command -v docker-compose &> /dev/null; then
    echo "=== Installing Docker Compose ==="
    VER="v2.27.0"
    sudo curl -L \
      "https://github.com/docker/compose/releases/download/${VER}/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "docker-compose already installed"
fi

docker-compose --version

############################################################
# PREPARE ENV FILE
############################################################

if [ ! -f .env ]; then
    echo "Creating .env from example"
    cp .env.example .env
fi

# Generate random password
RANDOM_PASSWORD=$(tr -dc 'a-z0-9' </dev/urandom | head -c 12)

if grep -q "^DB_PASSWORD=password" .env; then
    sed -i.bak "s/^DB_PASSWORD=.*/DB_PASSWORD=${RANDOM_PASSWORD}/" .env
    echo "Updated DB_PASSWORD = $RANDOM_PASSWORD"
fi

############################################################
# RUN DOCKER COMPOSE
############################################################

echo "=== Starting Docker Compose ==="
sudo docker-compose pull
sudo docker-compose up -d

sleep 5

############################################################
# FIND WEB CONTAINER NAME AUTOMATICALLY
############################################################

CURRENT_DIR=$(basename "$PWD")
POSSIBLE1="${CURRENT_DIR}-web-1"
POSSIBLE2="${CURRENT_DIR}_web-1"

if sudo docker ps --format '{{.Names}}' | grep -q "$POSSIBLE1"; then
    WEB="$POSSIBLE1"
elif sudo docker ps --format '{{.Names}}' | grep -q "$POSSIBLE2"; then
    WEB="$POSSIBLE2"
else
    echo "❌ ERROR: Web container not found."
    sudo docker ps
    exit 1
fi

echo "Detected web container: $WEB"

############################################################
# FIX PERMISSIONS
############################################################

sudo docker exec "$WEB" chmod -R 777 /var/www/html/.env
sudo docker exec "$WEB" chmod -R 777 /var/www/html/storage

############################################################
# GENERATE APP_KEY IF EMPTY
############################################################

if grep -q "^APP_KEY=$" .env; then
    echo "Generating APP_KEY..."
    sudo docker exec "$WEB" php artisan key:generate
fi

echo "=== DONE ==="
echo "Your private server is ready!"
echo "Access: http://YOUR_SERVER_IP/"
