// Servidor de AWS en el que se va a implantar la siguiente estructura
provider "aws" {
  region = "us-east-1"
}

#####################################
########### CREACIÓN VPC ############
#####################################

resource "aws_vpc" "tfg_asir_vpc" {
  cidr_block = "10.208.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "tfg-asir-vpc"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.tfg_asir_vpc.id
  cidr_block        = "10.208.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tfg-asir-subnet-public1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.tfg_asir_vpc.id
  cidr_block        = "10.208.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "tfg-asir-subnet-public2"
  }
}

resource "aws_subnet" "private_3" {
  vpc_id            = aws_vpc.tfg_asir_vpc.id
  cidr_block        = "10.208.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "tfg-asir-subnet-private3"
  }
}

resource "aws_subnet" "private_4" {
  vpc_id            = aws_vpc.tfg_asir_vpc.id
  cidr_block        = "10.208.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "tfg-asir-subnet-private4"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tfg_asir_vpc.id

  tags = {
    Name = "tfg-asir-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tfg_asir_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "tfg-asir-rtb-public"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "tfg-asir-nat"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tfg_asir_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "tfg-asir-rtb-private"
  }
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
################ EC2 ################
#####################################


// Creación de la instancia de Nginx - 1

resource "aws_instance" "nginx_1" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_1.id
  key_name      = aws_key_pair.ssh_key.key_name

  tags = {
    Name = "NGINX-1"
  }
}

// Creación de la instancia de Nginx - 2

resource "aws_instance" "nginx_2" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_2.id
  key_name      = aws_key_pair.ssh_key.key_name

  tags = {
    Name = "NGINX-2"
  }
}

// Creación de la instancia de Lemmy

resource "aws_instance" "lemmy" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_3.id
  key_name      = aws_key_pair.ssh_key.key_name
  user_data     = file("${path.module}/scripts/docker.sh")

  tags = {
    Name = "LEMMY-1"
  }
}

// Creación de la instancia de Gancio

resource "aws_instance" "gancio" {
  ami           = "ami-04b4f1a9cf54c11d0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_4.id
  key_name      = aws_key_pair.ssh_key.key_name

  tags = {
    Name = "GANCIO-1"
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
  subnet_ids = [aws_subnet.private_3.id]  # Solo en la subred privada 3
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
  subnet_ids = [aws_subnet.private_4.id]  # Solo en la subred privada 4
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
