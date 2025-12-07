#!/bin/bash

##############################################
# FIXED VERSION FOR BITNAMI + UBUNTU
# No systemd needed, install Docker correctly
##############################################

echo "=== Checking Docker installation ==="

if ! command -v docker &> /dev/null
then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
fi

if ! command -v docker-compose &> /dev/null
then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/2.29.2/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo "Docker installed version:"
docker --version
docker-compose --version

##############################################

# Create .env if missing
if [ ! -f .env ]; then
    cp .env.example .env
fi

# Generate random DB password
RANDOM_PASSWORD=$(tr -dc 'a-z0-9' </dev/urandom | head -c 12)

if grep -q "^DB_PASSWORD=password" .env; then
    sed -i.bak "s/^DB_PASSWORD=.*/DB_PASSWORD=${RANDOM_PASSWORD}/" .env
    echo "DB_PASSWORD updated: ${RANDOM_PASSWORD}"
else
    echo "DB_PASSWORD already set"
fi

##############################################
# RUN DOCKER COMPOSE
##############################################

echo "=== Starting Docker containers ==="

docker-compose pull
docker-compose up -d

sleep 5

##############################################
# FIX PERMISSIONS
##############################################

WEB_CONTAINER=$(docker ps --format "{{.Names}}" | grep "_web_1\|web-1" | head -n 1)

if [ -z "$WEB_CONTAINER" ]; then
    echo "ERROR: Web container not found!"
    docker ps
    exit 1
fi

echo "Using container: ${WEB_CONTAINER}"

docker exec -it "$WEB_CONTAINER" chmod -R 777 /var/www/html/storage
docker exec -it "$WEB_CONTAINER" chmod 777 /var/www/html/.env

##############################################
# GENERATE APP KEY
##############################################

if grep -q "^APP_KEY=$" .env; then
    echo "Generating APP_KEY..."
    docker exec -it "$WEB_CONTAINER" php artisan key:generate
fi

##############################################
echo "DONE!"
echo "Private server URL: http://your_ip_or_domain"
##############################################
