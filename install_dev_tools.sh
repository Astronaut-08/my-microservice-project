#!/bin/bash

set -e

echo "Перевірка наявності Docker"
if command -v docker >/dev/null 2>&1; then
    echo "Docker вже встановлено"
else
    echo "Docker не знайдено, відбувається встановлення..."
    # Add Docker's official GPG key:
    sudo apt update
    sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "Встановлення пройшло успішно!"
fi

echo "Перевірка наявності Docker Compose"
if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose вже встановлено"
else
    echo "Docker Compose не знайдено, відбувається встановлення..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    echo "Встановлення пройшло успішно!"
fi

echo "Перевірка наявності Python"
if command -v python3 >/dev/null 2>&1; then
    echo "Python вже встановлено"
else
    echo "Python не знайдено, відбувається встановлення..."
    sudo apt-get update
    sudo apt install -y python3 python3-pip python3-venv
    echo "Встановлення пройшло успішно!"
fi

echo "Перевірка наявності Django"
if command -v django-admin >/dev/null 2>&1; then
    echo "Django вже встановлено"
else
    echo "Django не знайдено, відбувається встановлення..."
    sudo apt-get update
    sudo apt-get install -y python3-django
    echo "Встановлення пройшло успішно!"
fi