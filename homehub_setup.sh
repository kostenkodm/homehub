#!/bin/bash

# Turn off the LED
sudo bash -c 'echo 0 > /sys/devices/platform/gpio-leds/leds/working/brightness'
# Change hostname
sudo hostnamectl hostname HomeHub
# Update package list
sudo apt update

# Install required packages
sudo apt-get install -y jq wget curl udisks2 libglib2.0-bin network-manager dbus apparmor-utils systemd-journal-remote lsb-release bluez systemd-timesyncd

# Download and install OS Agent
wget https://github.com/home-assistant/os-agent/releases/download/1.7.2/os-agent_1.7.2_linux_aarch64.deb
sudo dpkg -i os-agent_1.7.2_linux_aarch64.deb

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Download Home Assistant supervised installer
wget https://github.com/home-assistant/supervised-installer/releases/download/3.0.0/homeassistant-supervised.deb

# Install systemd-resolved
sudo apt-get install -y systemd-resolved

# Modify /etc/os-release
sudo sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Debian GNU\/Linux 12 (bookworm)"/' /etc/os-release

# Create post-reboot script
echo 'BYPASS_OS_CHECK=true sudo dpkg -i homeassistant-supervised.deb' > post-reboot.sh
echo "После перезагрузки выполните: bash post-reboot.sh"

# Reboot
sudo reboot
