#!/bin/bash

PROMETHEUS_FILE="/etc/prometheus/prometheus.yml"
PROMETHEUS_SERVICE="/etc/systemd/system/prometheus.service"

# Cosas previas a la instalación
sudo apt update
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus/

# Instalar Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v3.3.0-rc.0/prometheus-3.3.0-rc.0.linux-amd64.tar.gz
tar -zxvf prometheus-3.3.0-rc.0.linux-amd64.tar.gz
cd prometheus-3.3.0-rc.0.linux-amd64/
sudo cp promtool /usr/local/bin
sudo cp prometheus /usr/local/bin

sudo touch /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /etc/prometheus/prometheus.yml

# Implantando configuración
sudo cat > $PROMETHEUS_FILE << EOF
# Configuración Global.
global:
  scrape_interval: 15s 
  evaluation_interval: 15s
  scrape_timeout: 15s  
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090'] #Solo realizara el monitoreo del servidor local.

EOF

# Instalando Servicio
sudo cat > $PROMETHEUS_SERVICE << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

# Inicializando servicio
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
sudo systemctl status prometheus