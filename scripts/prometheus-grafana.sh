#!/bin/bash

# Instalación de Prometheus
sudo wget https://github.com/prometheus/prometheus/releases/download/v2.39.1/prometheus-2.39.1.linux-amd64.tar.gz
sudo tar -xzf prometheus-*linux-amd64.tar.gz
sudo mv prometheus-*linux-amd64 prometheus
sudo mkdir -p /var/lib/prometheus
sudo mkdir -p /etc/prometheus
sudo cp prometheus/prometheus.yml /etc/prometheus
sudo mv prometheus/prometheus prometheus/promtool /usr/local/bin/
sudo mv prometheus/consoles/ prometheus/console_libraries/ /etc/prometheus/

# Creación del usuario
sudo useradd --no-create-home --shell /bin/false prometheus
sudo chown -R prometheus:prometheus /opt/node_exporter

sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries

# Configurar servicio de Prometheus
sudo tee > /etc/systemd/system/prometheus.service > /dev/null << EOF
[Unit]
Description=Prometheus Server
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart= /usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start prometheus.service
sudo systemctl enable prometheus.service

# Instalación de Grafana (puerto 3000)
sudo apt install -y apt-transport-https software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null

sudo apt update
sudo apt install grafana -y
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Instalación de Node Exporter
sudo wget https://github.com/prometheus/node_exporter/releases/download/v1.3.0/node_exporter-1.3.0.linux-amd64.tar.gz -P /opt
sudo tar -xvf /opt/node_exporter-1.3.0.linux-amd64.tar.gz
sudo mv node_exporter-1.3.0.linux-amd64/ /opt/node_exporter

# Creación del servicio
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << EOF
[Unit]
Description=node_exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/node_exporter/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Añadimos el servidor de Prometheus
sudo tee /etc/prometheus/prometheus.yml > /dev/null << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files: []

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: 'node_exporter'
    static_configs:
      - targets:
        - '10.208.3.60:9100'
        - '10.208.4.70:9100'
        - '10.208.3.50:9100'
        - '10.208.1.100:9100'
        - '10.208.2.100:9100'
        - '10.208.4.80:9100'
EOF

sudo systemctl stop prometheus
sudo systemctl start prometheus