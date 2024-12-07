#!/usr/bin/env bash
set -e

echo "[MAIN SETUP] Prometheus, Grafana kurulumu başlıyor..."

# subnodes.env dosyasını yükle
source /root/humanode-monitoring-setup/subnodes.env


# ALT_NODES değişkenindeki IP adreslerini işleyelim
# Virgülle ayrılmış listeyi YAML formatına dönüştürmek için bir döngü kullanalım

NODES_ARRAY=(${ALT_NODES//,/ })

# Prometheus yml için bu array'i kullanacağız
SCRAPE_TARGETS=""
for ip in "${NODES_ARRAY[@]}"; do
  SCRAPE_TARGETS+="\"${ip}:9100\", "
done
# Son virgülü kaldırmak için bir hile: 
SCRAPE_TARGETS=$(echo $SCRAPE_TARGETS | sed 's/, $//')

sudo apt-get update -y
sudo apt-get install -y wget curl nano git apt-transport-https software-properties-common

PROM_VERSION="2.46.0"
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
sudo mv prometheus-${PROM_VERSION}.linux-amd64 /etc/prometheus
sudo useradd --no-create-home --shell /bin/false prometheus || true
sudo chown -R prometheus:prometheus /etc/prometheus
sudo cp /etc/prometheus/prometheus /usr/local/bin/
sudo cp /etc/prometheus/promtool /usr/local/bin/

sudo bash -c "cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/etc/prometheus/data
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

sudo bash -c "cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporters'
    static_configs:
      - targets: [${SCRAPE_TARGETS}]
EOF"

sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

# Grafana kurulumu (daha önce verdiğimiz örnekle aynı)
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt-get update
sudo apt-get install -y grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Ana sunucuda Node Exporter (isteğe bağlı)
NODE_EXPORTER_VERSION="1.6.1"
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /bin/false node_exporter || true
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

sudo bash -c 'cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

echo "[MAIN SETUP] Prometheus, Grafana ve Node Exporter kuruldu."
echo "Grafana varsayılan port: http://65.109.70.11:3000"
echo "Prometheus varsayılan port: http://65.109.70.11:9090"
