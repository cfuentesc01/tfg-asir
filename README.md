# 📌 Proyecto TFG - Implantación de Lemmy y Gancio en AWS

## 📖 Descripción
Este proyecto de Final de Grado (TFG) consiste en la implementación y configuración de **Lemmy** (una red social similar a Reddit) y **Gancio** (una plataforma de organización de eventos) en **AWS**.

Ambos servicios se desplegarán en un entorno seguro y escalable, con la integración de un sistema de notificaciones mediante **SMTP (Brevo)** para alertar a los usuarios sobre nuevos eventos.

## 🎯 Objetivos
- Implementar **Lemmy** y **Gancio** en AWS utilizando **Docker Compose** y **instalación nativa**.
- Configurar bases de datos **MySQL en RDS** para ambas aplicaciones.
- Desplegar **Nginx** como proxy inverso para gestionar el tráfico y los certificados SSL.
- Automatizar la instalación mediante **Bash y AWS CloudShell**.
- Implementar un servicio de **notificaciones por correo** con **SMTP (Brevo)**.
- Realizar copias de seguridad automáticas de las bases de datos en otra instancia.

## 🏗️ Arquitectura del Proyecto

![Screenshot](docs/estructura.png)

## 🛠️ Tecnologías Utilizadas
- **AWS** (EC2, RDS, VPC, CloudShell)
- **Ubuntu Server** (para las instancias EC2)
- **Nginx** (proxy inverso y gestión de SSL)
- **Docker & Docker Compose** (para Lemmy)
- **MySQL en AWS RDS** (almacenamiento de datos)
- **Bash y AWS CloudShell** (automatización)
- **Postfix/Brevo SMTP** (notificaciones de eventos por email)

## 🚀 Instalación y Despliegue

### 1️⃣ Desplegar proyecto en AWS
```bash
git clone https://github.com/cfuentesc01/tfg-asir.git
cd tfg-asir
chmod +x start.sh
./start.sh
```
