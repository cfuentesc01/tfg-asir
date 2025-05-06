// Servidor de AWS en el que se va a implantar la siguiente estructura
provider "aws" {
  region = "us-east-1"
}

# terraform init → Inicializa Terraform.
# terraform validate → Verifica la sintaxis.
# terraform plan → Simula los cambios.
# terraform apply → Aplica los cambios en AWS.
# terraform destroy → Elimina los recursos.

#####################################
########### CREACIÓN VPC ############
#####################################

resource "aws_vpc" "tfg_asir_vpc" {
  cidr_block       = "10.208.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "tfg_asir_vpc-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.tfg_asir_vpc.id
  cidr_block        = "10.208.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "tfg_asir_vpc-subnet-public1-us-east-1a"
  }
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.tfg_asir_vpc.id
  cidr_block        = "10.208.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "tfg_asir_vpc-subnet-public2-us-east-1b"
  }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.tfg_asir_vpc.id
  cidr_block        = "10.208.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "tfg_asir_vpc-subnet-private1-us-east-1a"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.tfg_asir_vpc.id
  cidr_block        = "10.208.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "tfg_asir_vpc-subnet-private2-us-east-1b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tfg_asir_vpc.id

  tags = {
    Name = "tfg_asir_vpc-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tfg_asir_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "tfg_asir_vpc-rtb-public"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "tfg_asir_vpc-eip-us-east-1a"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "tfg_asir_vpc-nat-public1-us-east-1a"
  }
}

resource "aws_route_table" "private1" {
  vpc_id = aws_vpc.tfg_asir_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "tfg_asir_vpc-rtb-private1-us-east-1a"
  }
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1.id
}

resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.tfg_asir_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "tfg_asir_vpc-rtb-private2-us-east-1b"
  }
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private2.id
}


#####################################
######## CREACIÓN CLAVES SSH ########
#####################################

// Genera una clave privada RSA de 4096 bits
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

// Guarda la clave privada en formato .pem
resource "local_file" "private_key" {
  filename        = "${path.module}/tfg-key.pem"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

// Crea la clave SSH en AWS para EC2
resource "aws_key_pair" "ssh_key" {
  key_name   = "tfg-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

#####################################
########## SECURITY GROUPS ##########
#####################################

// Creación del grupo de seguridad de Nginx - 1

resource "aws_security_group" "nginx-1_sg" {
  name        = "nginx-1-security-group"
  description = "Permitir trafico HTTP, HTTPS y SSH"
  vpc_id      = aws_vpc.tfg_asir_vpc.id

  # Permitir SSH 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico HTTP desde cualquier lugar
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico HTTPS desde cualquier lugar
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir acceso HTTPS a la interfaz web de OpenMediaVault
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Interfaz Web OpenMediaVault desde la VPC"
  }

  # Permitir salida a cualquier destino
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-NGINX-1"
  }
}

// Creación del grupo de seguridad de Nginx - 2

resource "aws_security_group" "nginx-2_sg" {
  name        = "nginx-2-security-group"
  description = "Permitir trafico HTTP, HTTPS y SSH"
  vpc_id      = aws_vpc.tfg_asir_vpc.id

  # Permitir SSH solo desde tu IP (reemplaza con tu IP pública)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico HTTP desde cualquier lugar
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico HTTPS desde cualquier lugar
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico Gancio
  ingress {
    from_port   = 13120
    to_port     = 13120
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico SMTP
  ingress {
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 465
    to_port     = 465
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Global para SMTPS
  }

  # Permitir salida a cualquier destino
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-NGINX-2"
  }
}

// Creación del grupo de seguridad de Lemmy

resource "aws_security_group" "lemmy_sg" {
  name        = "lemmy-security-group"
  description = "Reglas de seguridad para la instancia de Lemmy"
  vpc_id      = aws_vpc.tfg_asir_vpc.id  

  # Permitir SSH solo desde una IP específica o bastión
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  # Permitir acceso a Lemmy desde las instancias NGINX
  ingress {
    from_port   = 8536
    to_port     = 8536
    protocol    = "tcp"
    security_groups = [aws_security_group.nginx-1_sg.id]  # Asegúrate de que el SG de NGINX está definido
  }

  # Permitir acceso a PostgreSQL solo dentro de la subred privada
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.208.3.0/24"]  # Ajusta a la subred privada correcta
  }

  # Permitir SMB para backups
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir que Prometheus acceda a Gancio para monitorización (puerto 9100)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida permitida a cualquier destino (Internet vía NAT Gateway)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Lemmy Security Group"
  }
}

// Creación del grupo de seguridad de Gancio con el PostFix

resource "aws_security_group" "gancio_sg" {
  name        = "gancio-security-group"
  description = "Reglas de seguridad para la instancia de Gancio con Postfix y RDS"
  vpc_id      = aws_vpc.tfg_asir_vpc.id  # Asegura que esté en la VPC correcta

  # Permitir acceso SSH desde cualquier instancia dentro de la VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto Gancio
  ingress {
    from_port   = 13120
    to_port     = 13120
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir SMTPS (SMTP seguro) y Submission (STARTTLS)
  ingress {
    from_port   = 465
    to_port     = 465
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Global para SMTPS
  }

  ingress {
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Global para Submission (STARTTLS)
  }

  # Permitir acceso a MySQL RDS desde Gancio
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Acceso desde cualquier instancia en la VPC
  }

  # Permitir SMB para backups
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir que Prometheus acceda a Gancio para monitorización (puerto 9100)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Toda la VPC puede monitorizar
  }

  # Permitir salida a Internet 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Gancio Security Group"
  }
}


// Creación del grupo de seguridad de Prometheus

resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus-security-group"
  description = "Reglas de seguridad para la instancia de Prometheus con Grafana"
  vpc_id      = aws_vpc.tfg_asir_vpc.id 

  # Permitir acceso SSH desde cualquier instancia dentro de la VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Toda la VPC puede acceder por SSH
  }

  # Permitir acceso a la interfaz web de Prometheus (9090) desde cualquier instancia de la VPC
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Toda la VPC puede acceder a Prometheus
  }

  # Permitir recepción de métricas desde cualquier instancia de la VPC
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Toda la VPC puede enviar métricas
  }

  # Permitir acceso a la interfaz web de Grafana (3000) desde cualquier instancia de la VPC
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Toda la VPC puede acceder a Grafana
  }

  # Permitir salida a Internet (para actualizaciones, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-PROMETHEUS"
  }
}

// Creación del grupo de seguridad de Backups con OpenMediaVault

resource "aws_security_group" "backups_sg" {
  name        = "backups_sg"
  description = "Permitir acceso a OpenMediaVault y conexiones a RDS"
  vpc_id      = aws_vpc.tfg_asir_vpc.id

  # Permitir SSH desde cualquier instancia dentro de la VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH desde la VPC"
  }

  # Permitir acceso HTTPS a la interfaz web de OpenMediaVault
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Interfaz Web OpenMediaVault desde la VPC"
  }

    # Permitir acceso HTTPS a la interfaz web de OpenMediaVault
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Interfaz Web OpenMediaVault desde la VPC"
  }

  # Permitir conexión a MySQL RDS
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Acceso a MySQL RDS desde Backups"
  }

  # Permitir SMB para backups
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir conexión a PostgreSQL RDS
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Acceso a PostgreSQL RDS desde Backups"
  }

  # Reglas de salida: permitir tráfico saliente a cualquier destino
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "Backups SG"
  }
}


#####################################
################ EC2 ################
#####################################


// Creación de la instancia de Nginx - 1

resource "aws_instance" "nginx_1" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t2.micro"
  private_ip    = "10.208.1.100"
  associate_public_ip_address = true
  subnet_id     = aws_subnet.public1.id
  key_name      = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.nginx-1_sg.id]

  tags = {
    Name = "NGINX-1"
  }
}

// Creación de la instancia de Nginx - 2

resource "aws_instance" "nginx_2" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t2.micro"
  private_ip    = "10.208.2.100"
  associate_public_ip_address = true
  subnet_id     = aws_subnet.public2.id
  key_name      = aws_key_pair.ssh_key.key_name
  security_groups = [aws_security_group.nginx-2_sg.id]
  tags = {
    Name = "NGINX-2"
  }
}

// Creación de la instancia de Lemmy

resource "aws_instance" "lemmy" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t3.medium"
  private_ip    = "10.208.3.50"
  subnet_id     = aws_subnet.private1.id
  key_name      = aws_key_pair.ssh_key.key_name
  security_groups = [aws_security_group.lemmy_sg.id]

  # user_data = file("scripts/lemmy.sh") 

  tags = {
    Name = "LEMMY-1"
  }

    root_block_device {
    volume_size = 50  # Disco duro
    volume_type = "gp3"
  }
}

// Creación de la instancia de Backups con OpenMediaVault

resource "aws_instance" "backups" {
  ami           = "ami-0b8d5b17b11c0c9e4"
  instance_type = "t3.small"
  private_ip    = "10.208.3.60"
  subnet_id     = aws_subnet.private1.id
  key_name      = aws_key_pair.ssh_key.key_name
  security_groups = [aws_security_group.backups_sg.id]

  tags = {
    Name = "BACKUPS"
  }

  root_block_device {
    volume_size = 20  # Disco raíz
    volume_type = "gp3"
  }

  ebs_block_device {
    device_name = "/dev/xvdf"  # Primer disco (RAID 1)
    volume_size = 30
    volume_type = "gp3"
  }

  ebs_block_device {
    device_name = "/dev/xvdg"  # Segundo disco (RAID 1)
    volume_size = 30
    volume_type = "gp3"
  }
}

// Creación de la instancia de Gancio

resource "aws_instance" "gancio" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t2.micro"
  private_ip    = "10.208.4.70"
  subnet_id     = aws_subnet.private2.id
  key_name      = aws_key_pair.ssh_key.key_name
  security_groups = [aws_security_group.gancio_sg.id]

  user_data = file("scripts/gancio.sh") 

  tags = {
    Name = "GANCIO-1"
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
}


// Creación de la instancia de Prometheus con Grafana

resource "aws_instance" "prometheus" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t2.micro"
  private_ip    = "10.208.4.80"
  subnet_id     = aws_subnet.private2.id
  key_name      = aws_key_pair.ssh_key.key_name
  security_groups = [aws_security_group.prometheus_sg.id]

  tags = {
    Name = "PROMETHEUS"
  }
}


#####################################
############ CREACIÓN RDS ###########
#####################################

// RDS PostgreSQL de Lemmy
resource "aws_db_instance" "rds_postgres_lemmy" {
  allocated_storage    = 20
  engine              = "postgres"
  engine_version      = "15"
  instance_class      = "db.t3.micro"
  identifier          = "lemmy-rds-postgres"
  username           = "carlosfc"
  password           = "1234567890asd."
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds_sg_lemmy.id]
  db_subnet_group_name = aws_db_subnet_group.lemmy_rds_subnet_group.name
  multi_az            = false  # No usar Alta Disponibilidad para forzar 1 sola subred

  tags = {
    Name = "RDS-LEMMY"
  }
}

resource "aws_db_subnet_group" "lemmy_rds_subnet_group" {
  name       = "lemmy-rds-subnet-group"
  subnet_ids = [aws_subnet.private2.id, aws_subnet.private1.id] 

  tags = {
    Name = "Lemmy RDS Subnet Group"
  }
}

resource "aws_security_group" "rds_sg_lemmy" {
  vpc_id = aws_vpc.tfg_asir_vpc.id
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.208.0.0/16"]  # Permitir conexiones dentro de la VPC
  }
}


// RDS MySQL de Gancio
resource "aws_db_instance" "rds_mysql_gancio" {
  allocated_storage    = 20
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  identifier          = "gancio-rds-mysql"
  username           = "carlosfc"
  password           = "1234567890asd."
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds_sg_gancio.id]
  db_subnet_group_name = aws_db_subnet_group.gancio_rds_subnet_group.name
  multi_az            = false  # No usar Alta Disponibilidad para forzar 1 sola subred

  tags = {
    Name = "RDS-GANCIO"
  }
}

resource "aws_db_subnet_group" "gancio_rds_subnet_group" {
  name       = "gancio-rds-subnet-group"
  subnet_ids = [aws_subnet.private2.id, aws_subnet.private1.id] 

  tags = {
    Name = "Gancio RDS Subnet Group"
  }
}

resource "aws_security_group" "rds_sg_gancio" {
  vpc_id = aws_vpc.tfg_asir_vpc.id
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.208.0.0/16"]  # Permitir conexiones dentro de la VPC
  }
}
