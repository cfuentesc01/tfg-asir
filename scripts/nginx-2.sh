#!/bin/bash

# Archivo de configuracion
CONFIG_FILE="/etc/nginx/sites-enabled/gancio.conf"

# Update and install necessary packages
apt-get update -y
apt-get install -y curl certbot

# Set up DuckDNS - Update the DuckDNS IP every 5 minutes
echo "Setting up DuckDNS update script..."
sudo mkdir -p /opt/duckdns
sudo cat <<DUCKDNS_SCRIPT > /opt/duckdns/duckdns.sh
#!/bin/bash
echo "Updating DuckDNS: gancio-tfg.duckdns.org"
curl -k "https://www.duckdns.org/update?domains=gancio-tfg.duckdns.org&token=ec9561c1-5778-489f-a589-7c4b12291f28&ip=" -o /opt/duckdns/duck.log
DUCKDNS_SCRIPT
chmod +x /opt/duckdns/duckdns.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/duckdns.sh >/dev/null 2>&1") | crontab -

# Update DuckDNS immediately to set the IP
echo "Updating DuckDNS IP..."
/opt/duckdns/duckdns.sh
sleep 30

# Detiene temporalmente cualquier proceso en el puerto 80 (como Apache o NGINX)
echo "Stopping any web server using port 80..."
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# Obtain SSL certificate in standalone mode (non-interactive)
echo "Obtaining SSL certificate using certbot..."
certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email carlos@gmail.com \
  -d "gancio-tfg.duckdns.org"

apt-get install nginx -y
apt install nginx-extras -y

sudo tee > $CONFIG_FILE > /dev/null << EOF
# Redirección global HTTP -> HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name gancio-tfg.duckdns.org;
    return 301 https://$host$request_uri;
}

# Gancio - Servicio principal (Puerto 443)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name gancio-tfg.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/gancio-tfg.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/gancio-tfg.duckdns.org/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/gancio-tfg.duckdns.org/chain.pem;
    ssl_protocols TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;

    client_max_body_size 80m;
    keepalive_timeout 70;
    sendfile on;

    location / {
        proxy_pass http://10.208.4.70:13120;
        proxy_http_version 1.1;
        proxy_redirect off;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";

        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
    }

    error_log /var/log/nginx/gancio_error.log;
    access_log /var/log/nginx/gancio_access.log;
}

# Prometheus - Monitorización (Puerto 8443)
server {
    listen 8443 ssl http2;
    listen [::]:8443 ssl http2;
    server_name gancio-tfg.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/gancio-tfg.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/gancio-tfg.duckdns.org/privkey.pem;
    ssl_protocols TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        proxy_pass http://10.208.4.80:9090;
        proxy_http_version 1.1;
        proxy_redirect off;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;

        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
    }

    error_log /var/log/nginx/prometheus_error.log;
    access_log /var/log/nginx/prometheus_access.log;
}

# Grafana - Dashboard de métricas (Puerto 8444)
server {
    listen 8444 ssl http2;
    listen [::]:8444 ssl http2;
    server_name gancio-tfg.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/gancio-tfg.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/gancio-tfg.duckdns.org/privkey.pem;
    ssl_protocols TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        proxy_pass http://10.208.4.80:3000;
        proxy_http_version 1.1;
        proxy_redirect off;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";

        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;

        proxy_connect_timeout 90;
        proxy_send_timeout 90;
        proxy_read_timeout 90;
        send_timeout 90;
    }

    error_log /var/log/nginx/grafana_error.log;
    access_log /var/log/nginx/grafana_access.log;
}
EOF

#sudo ln -s $CONFIG_FILE $LINK_FILE

# Optimización
sudo mkdir -p /var/cache/nginx/gancio
sudo chown www-data: /var/cache/nginx/gancio

# Cache
#echo "proxy_cache_path /var/cache/nginx/gancio keys_zone=gancio_cache:1g max_size=80m inactive=1w;" | sudo tee -a /etc/nginx/nginx.conf

# Reiniciar Nginx
sudo systemctl daemon-reload
sudo systemctl reload nginx

# Monitorización
sudo useradd --no-create-home --shell /bin/false prometheus
sudo chown -R prometheus:prometheus /opt/node_exporter
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