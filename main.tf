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

resource "aws_instance" "nginx_1" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "NGINX-1"
  }
}

resource "aws_instance" "nginx_2" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_2.id

  tags = {
    Name = "NGINX-2"
  }
}

resource "aws_instance" "lemmy" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_3.id

  tags = {
    Name = "LEMMY"
  }
}

resource "aws_instance" "gancio" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_4.id

  tags = {
    Name = "GANCIO"
  }
}

resource "aws_db_instance" "rds_mysql" {
  allocated_storage    = 20
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  identifier          = "tfg-rds-mysql"
  username           = "admin"
  password           = "securepassword"
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

  tags = {
    Name = "RDS MySQL"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private_3.id, aws_subnet.private_4.id]
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.tfg_asir_vpc.id
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.208.0.0/16"]
  }
}

// Creación del RDS de Lemmy

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

  tags = {
    Name = "RDS MySQL Lemmy"
  }
}

resource "aws_db_subnet_group" "lemmy_rds_subnet_group" {
  name       = "lemmy-rds-subnet-group"
  subnet_ids = [aws_subnet.private_3.id, aws_subnet.private_4.id]
}

resource "aws_security_group" "rds_sg_lemmy" {
  vpc_id = aws_vpc.tfg_asir_vpc.id
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.208.0.0/16"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
