#!/bin/bash

# Скрипт для установки Home Assistant Supervised с отложенной установкой после перезагрузки
# Проверьте, что запускаете от имени root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт от имени root"
  exit 1
fi

# Установка имени хоста
hostnamectl set-hostname HomeHub

# Отключение светодиода (при наличии)
echo 0 > /sys/devices/platform/gpio-leds/leds/working/brightness 2>/dev/null || true

# Обновление списков пакетов
apt update

# Установка необходимых пакетов
apt-get install -y \
  jq wget curl udisks2 libglib2.0-bin network-manager \
  dbus apparmor-utils systemd-journal-remote lsb-release \
  bluez systemd-timesyncd systemd-resolved \
  cifs-utils nfs-common

# Корректировка /etc/os-release для обхода проверки ОС
# Сохраняем оригинальную версию, но указываем ID=debian и оставляем VERSION_ID=12 (bookworm)
sed -i \
  -e 's|^ID=.*|ID=debian|' \
  -e 's|^VERSION_ID=.*|VERSION_ID="12"|' \
  -e 's|^PRETTY_NAME=.*|PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"|' \
  /etc/os-release

# Загрузка и установка OS Agent (версия 1.7.2 для aarch64)
wget https://github.com/home-assistant/os-agent/releases/download/1.7.2/os-agent_1.7.2_linux_aarch64.deb -P /root
dpkg -i /root/os-agent_1.7.2_linux_aarch64.deb

# Установка Docker
curl -fsSL https://get.docker.com -o /root/get-docker.sh
bash /root/get-docker.sh
# Добавление пользователя в группу docker
groupadd -f docker
usermod -aG docker "$SUDO_USER"

# Загрузка пакета Home Assistant Supervised для установки после перезагрузки
wget https://github.com/home-assistant/supervised-installer/releases/download/3.0.0/homeassistant-supervised.deb -P /root

# Создание скрипта post-reboot
cat << 'EOF' > /root/post-reboot.sh
#!/bin/bash
exec &>> /var/log/post-reboot.log

echo "=== Начинается установка Home Assistant Supervised ==="
# Обход проверки ОС и указание типа машины
export BYPASS_OS_CHECK=true
export MACHINE=odroid-c2
# Устанавливаем пакет с указанием MACHINE
/usr/bin/env MACHINE="$MACHINE" BYPASS_OS_CHECK="$BYPASS_OS_CHECK" \
  /usr/bin/dpkg -i /root/homeassistant-supervised.deb

# Отключаем этот сервис после выполнения
/usr/bin/systemctl disable post-reboot.service

echo "=== Установка завершена. Логи: /var/log/post-reboot.log ==="
EOF
chmod +x /root/post-reboot.sh

# Создание systemd-сервиса для выполнения post-reboot.sh после загрузки сети
cat << 'EOF' > /etc/systemd/system/post-reboot.service
[Unit]
Description=Установка Home Assistant Supervised после перезагрузки
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/root/post-reboot.sh

[Install]
WantedBy=multi-user.target
EOF

# Включение сервиса
systemctl daemon-reload
systemctl enable post-reboot.service

# Перезагрузка системы
echo "Система будет перезагружена для завершения установки Home Assistant Supervised."
reboot
