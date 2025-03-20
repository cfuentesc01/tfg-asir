// Servidor de AWS en el que se va a implantar la siguiente estructura
provider "aws" {
  region = "us-east-1"
}

// Creación de la VPC

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

// Creación de la instancia de Nginx - 1

resource "aws_instance" "nginx_1" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "NGINX-1"
  }
}

// Creación de la instancia de Nginx - 2

resource "aws_instance" "nginx_2" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_2.id

  tags = {
    Name = "NGINX-2"
  }
}

// Creación de la instancia de Lemmy

resource "aws_instance" "lemmy" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_3.id

  tags = {
    Name = "LEMMY-1"
  }
}

// Creación de la instancia de Gancio

resource "aws_instance" "gancio" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_4.id

  tags = {
    Name = "GANCIO-1"
  }
}

// RDS MySQL de Lemmy
resource "aws_db_instance" "rds_mysql_lemmy" {
  allocated_storage    = 20
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  identifier          = "lemmy-rds-mysql"
  username           = "carlosfc"
  password           = "1234567890asd."
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds_sg_lemmy.id]
  db_subnet_group_name = aws_db_subnet_group.lemmy_rds_subnet_group.name
  multi_az            = false  # No usar Alta Disponibilidad para forzar 1 sola subred

  tags = {
    Name = "RDS MySQL Lemmy"
  }
}

resource "aws_db_subnet_group" "lemmy_rds_subnet_group" {
  name       = "lemmy-rds-subnet-group"
  subnet_ids = [aws_subnet.private_3.id]  # Solo en la subred privada 3
}

resource "aws_security_group" "rds_sg_lemmy" {
  vpc_id = aws_vpc.tfg_asir_vpc.id
  
  ingress {
    from_port   = 3306
    to_port     = 3306
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
    Name = "RDS MySQL Gancio"
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








// Instancia para hacer backups
resource "aws_instance" "backup_server" {
  ami                    = "ami-12345678" 
  instance_type          = "t2.micro"  
  subnet_id              = aws_subnet.private_3.id
  vpc_security_group_ids = [aws_security_group.backup_sg.id]
  key_name               = "mi-clave-aws" # Sustituye por tu par de claves
  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "Servidor de Backups"
  }
}

// Grupo de seguridad para instancias de Backups
resource "aws_security_group" "backup_sg" {
  vpc_id = aws_vpc.tfg_asir_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.208.0.0/16"]  # Solo accesible dentro de la VPC
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.208.0.0/16"]  # Acceso solo a MySQL dentro de la VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Volúmenes EBS para RAID 1 (50GB x 2)
resource "aws_ebs_volume" "backup_raid_1" {
  availability_zone = aws_instance.backup_server.availability_zone
  size             = 50
  type             = "gp3"

  tags = {
    Name = "RAID1-1"
  }
}

resource "aws_ebs_volume" "backup_raid_2" {
  availability_zone = aws_instance.backup_server.availability_zone
  size             = 50
  type             = "gp3"

  tags = {
    Name = "RAID1-2"
  }
}

// Volumen adicional de 50GB para almacenamiento
resource "aws_ebs_volume" "backup_secondary" {
  availability_zone = aws_instance.backup_server.availability_zone
  size             = 50
  type             = "gp3"

  tags = {
    Name = "Backup-Extra"
  }
}

// Adjuntar volúmenes RAID 1 a la instancia
resource "aws_volume_attachment" "attach_raid_1" {
  device_name = "/dev/xvdf"
  instance_id = aws_instance.backup_server.id
  volume_id   = aws_ebs_volume.backup_raid_1.id
}

resource "aws_volume_attachment" "attach_raid_2" {
  device_name = "/dev/xvdg"
  instance_id = aws_instance.backup_server.id
  volume_id   = aws_ebs_volume.backup_raid_2.id
}

// Adjuntar volumen secundario de 50GB
resource "aws_volume_attachment" "attach_secondary" {
  device_name = "/dev/xvdh"
  instance_id = aws_instance.backup_server.id
  volume_id   = aws_ebs_volume.backup_secondary.id
}

// Creación del bucket S3
resource "aws_s3_bucket" "backup_bucket" {
  bucket = "tfg-backups-mysql"

  tags = {
    Name        = "MySQL Backups"
    Environment = "Production"
  }
}

// Configurando Glacier
resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  bucket = aws_s3_bucket.backup_bucket.id

  rule {
    id     = "MoveToGlacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365  # Borrar backups después de un año
    }
  }
}
