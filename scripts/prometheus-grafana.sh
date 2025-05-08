#!/bin/bash

PROMETHEUS_FILE="/etc/prometheus/prometheus.yml"
PROMETHEUS_SERVICE="/etc/systemd/system/prometheus.service"
NODE_EXPORTER="/etc/systemd/system/node_exporter.service"

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

# Instalando Node Exporter
sudo useradd -m -s /bin/false node_exporter
cd
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar -zxpvf node_exporter-1.5.0.linux-amd64.tar.gz
cd node_exporter-1.5.0.linux-amd64
sudo cp node_exporter /usr/local/bin/
sudo chown -R node_exporter:node_exporter /usr/local/bin/node_exporter

echo "[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target" | sudo tee $NODE_EXPORTER > /dev/null

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
sudo systemctl status node_exporter

echo "# Global config
global:
  scrape_interval:     15s
  evaluation_interval: 15s
  scrape_timeout: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
  - job_name: 'node_exporter'
    static_configs:
    - targets: ['localhost:9100']" | sudo tee $PROMETHEUS_FILE > /dev/null

sudo systemctl restart prometheus.service


# Instalación de Grafana
cd
sudo apt-get install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install grafana

sudo systemctl start grafana-server
sudo systemctl enable grafana-server