#!/bin/bash

PROMETHEUS_FILE="/etc/prometheus/prometheus.yml"
PROMETHEUS_SERVICE="/etc/systemd/system/prometheus.service"

# Cosas previas a la instalación
sudo apt update
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Instalar Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v3.3.0-rc.0/prometheus-3.3.0-rc.0.linux-amd64.tar.gz
tar -zxvf prometheus-3.3.0-rc.0.linux-amd64.tar.gz
cd prometheus-3.3.0-rc.0.linux-amd64/
sudo cp promtool /usr/local/bin
sudo cp prometheus /usr/local/bin

# Crear el archivo de configuración de Prometheus con contenido directamente
echo "# Configuración Global.
global:
  scrape_interval: 15s 
  evaluation_interval: 15s
  scrape_timeout: 15s  
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090'] #Solo realizara el monitoreo del servidor local." | sudo tee $PROMETHEUS_FILE > /dev/null

# Cambiar propiedad y permisos para que prometheus pueda escribir en el archivo
sudo chown prometheus:prometheus $PROMETHEUS_FILE

# Crear el servicio de Prometheus con contenido directamente
echo "[Unit]
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
WantedBy=multi-user.target" | sudo tee $PROMETHEUS_SERVICE > /dev/null

# Cambiar propiedad y permisos para que prometheus pueda leer el archivo del servicio
sudo chown root:root $PROMETHEUS_SERVICE

# Inicializando servicio
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
sudo systemctl status prometheus
