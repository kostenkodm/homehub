#!/bin/bash

# Проверка, запущен ли скрипт от имени root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт от имени root"
  exit 1
fi

hostnamectl set-hostname HomeHub

# Отключение светодиода
echo 0 > /sys/devices/platform/gpio-leds/leds/working/brightness

# Обновление списка пакетов
apt update

# Установка необходимых пакетов
apt-get install -y jq wget curl udisks2 libglib2.0-bin network-manager dbus apparmor-utils systemd-journal-remote lsb-release bluez systemd-timesyncd

# Загрузка и установка OS Agent
wget https://github.com/home-assistant/os-agent/releases/download/1.7.2/os-agent_1.7.2_linux_aarch64.deb -P /root
dpkg -i /root/os-agent_1.7.2_linux_aarch64.deb

# Установка Docker
curl -fsSL https://get.docker.com -o /root/get-docker.sh
sh /root/get-docker.sh

# Добавление пользователя в группу docker
usermod -aG docker $SUDO_USER

# Загрузка установщика Home Assistant Supervised
wget https://github.com/home-assistant/supervised-installer/releases/download/3.0.0/homeassistant-supervised.deb -P /root

# Установка systemd-resolved
apt-get install -y systemd-resolved

# Изменение файла /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Debian GNU\/Linux 12 (bookworm)"/' /etc/os-release

# Создание скрипта для выполнения после перезагрузки
cat << EOF > /root/post-reboot.sh
#!/bin/bash
echo "Начинается установка Home Assistant..." >> /var/log/post-reboot.log
BYPASS_OS_CHECK=true dpkg -i /root/homeassistant-supervised.deb >> /var/log/post-reboot.log 2>&1
systemctl disable post-reboot.service
echo "Попытка установки Home Assistant завершена. Подробности в /var/log/post-reboot.log" >> /var/log/post-reboot.log
EOF

# Назначение прав на выполнение скрипта
chmod +x /root/post-reboot.sh

# Создание systemd сервиса для выполнения скрипта после перезагрузки
cat << EOF > /etc/systemd/system/post-reboot.service
[Unit]
Description=Run post-reboot script
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /root/post-reboot.sh

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd и включение сервиса
systemctl daemon-reload
systemctl enable post-reboot.service

# Сообщение пользователю и перезагрузка
echo "Система будет перезагружена. После перезагрузки проверьте статус установки в /var/log/post-reboot.log"
reboot
