# 📌 Proyecto TFG - Implantación de Lemmy y Gancio en AWS

## 📖 Descripción
Este proyecto de Final de Grado (TFG) consiste en la implementación y configuración de Lemmy (una red social similar a Reddit) y Gancio (una plataforma de organización de eventos) en AWS.

Ambos servicios se desplegarán en un entorno seguro y escalable, con la integración de un sistema de notificaciones mediante un servidor de correo self-hosted para alertar a los usuarios sobre nuevos eventos. Además, se incorporará monitorización y medidas de seguridad avanzadas en toda la infraestructura, y se automatizará el despliegue con Terraform.

## 🎯 Objetivos
- Implementar **Lemmy** y **Gancio** en AWS utilizando **Docker Compose** y **instalación nativa**.
- Configurar bases de datos **MySQL en RDS** para ambas aplicaciones.
- Desplegar **Nginx** como proxy inverso para gestionar el tráfico y los certificados SSL.
- Automatizar la instalación mediante Terraform.
- Implementar un servicio de notificaciones por correo con un servidor de correo self-hosted con PostFix.
- Incorporar un sistema de monitorización con Zabbix
- Implementar medidas de seguridad como firewall, reglas de seguridad estrictas.
- Realizar copias de seguridad automáticas de las bases de datos en otra instancia.

## 🏗️ Arquitectura del Proyecto

![Screenshot](docs/estructura.png)

## 🛠️ Tecnologías Utilizadas
- **AWS** (EC2, RDS, VPC, Route 53)
- **Ubuntu Server** (para las instancias EC2)
- **Nginx** (proxy inverso y gestión de SSL)
- **Docker & Docker Compose** (para Lemmy)
- **MySQL en AWS RDS** (almacenamiento de datos)
- **Terraform** (automatización)
- **Zabbix** (monitorización y visualización de recursos)
- **Postfix SMTP** (notificaciones de eventos por email)
- **Firewall y reglas IAM estrictas** (seguridad)

## 🚀 Instalación y Despliegue

### 1️⃣ Desplegar proyecto en AWS
```bash
git clone https://github.com/cfuentesc01/tfg-asir.git
cd tfg-asir
./main.tf
```
