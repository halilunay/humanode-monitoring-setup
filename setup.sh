#!/usr/bin/env bash
set -e

echo "--------------------------------------------"
echo "Humanode Alt Sunucu Otomatik Kurulum Scripti"
echo "--------------------------------------------"

# Gerekli paketlerin kurulumu
echo "[INFO] Gerekli paketler kuruluyor..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip nano curl jq

# Python kütüphanelerinin kurulumu
echo "[INFO] Python kütüphaneleri kuruluyor..."
sudo pip3 install python-telegram-bot==13.15 requests

# Node Exporter kurulumu
echo "[INFO] Node Exporter kuruluyor..."
NODE_EXPORTER_VERSION="1.6.1"
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /bin/false node_exporter || true
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Node Exporter service
sudo bash -c 'cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'

echo "[INFO] Node Exporter servisi etkinleştiriliyor..."
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# check_bioauth.py scriptini oluştur
echo "[INFO] check_bioauth.py scriptini indiriliyor..."
wget -O /root/check_bioauth.py https://raw.githubusercontent.com/halilunay/humanode-monitoring-setup/main/check_bioauth.py
sudo chmod +x /root/check_bioauth.py

# Ortam değişkenlerini al
echo "[INFO] Lütfen aşağıdaki bilgileri giriniz."
read -p "BOT_TOKEN girin: " BOT_TOKEN_INPUT
read -p "CHAT_ID girin: " CHAT_ID_INPUT
read -p "NODE_IP girin: " NODE_IP_INPUT

sudo bash -c "cat > /root/check_bioauth.env <<EOF
BOT_TOKEN=\"$BOT_TOKEN_INPUT\"
CHAT_ID=\"$CHAT_ID_INPUT\"
NODE_IP=\"$NODE_IP_INPUT\"
EOF"

# check_bioauth.service oluşturma
echo "[INFO] check_bioauth servisi oluşturuluyor..."
wget -O /etc/systemd/system/check_bioauth.service https://raw.githubusercontent.com/halilunay/humanode-monitoring-setup/main/check_bioauth.service

sudo systemctl daemon-reload
sudo systemctl enable check_bioauth.service
sudo systemctl start check_bioauth.service

echo "[INFO] Kurulum tamamlandı. Servis durumunu kontrol edin:"
sudo systemctl status check_bioauth.service
