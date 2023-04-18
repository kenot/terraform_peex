provider "aws" {
    region = "us-east-1"
}

# Create VPC Resource Block
resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main"
  }
}

# Create Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "192.168.0.0/16"
  map_public_ip_on_launch = true
}

# Create Internet Gateway
resource "aws_internet_gateway" "ig_main" {
  vpc_id = aws_vpc.main.id
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig_main.id
}

#Create Security Group
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

# Create an EC2 Resource Block
resource "aws_instance" "Ubuntu" {
    ami = "ami-0557a15b87f6559cf"
    instance_type = "t2.micro"

    key_name = aws_key_pair.gen_key_pair.key_name
    vpc_security_group_ids = [aws_security_group.allow_tls.id]
    security_groups = [aws_security_group.allow_tls.id]
    subnet_id = aws_subnet.public_subnet.id
}

# Automatically generated key 'gen_tls_pk':
resource "tls_private_key" "gen_tls_pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Automatically generated key_pair 'gen_key_pair':
resource "aws_key_pair" "gen_key_pair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.gen_tls_pk.public_key_openssh
}

# File to save .pem key to:
resource "local_file" "key_local_file" {
    content     = tls_private_key.gen_tls_pk.private_key_pem
    filename    = var.key_file
}

resource "aws_db_instance" "rds_instance" {
  identifier                = "${var.rds_instance_identifier}"
  allocated_storage         = 5
  engine                    = "mysql"
  engine_version            = "5.6.35"
  instance_class            = "db.t2.micro"
  db_name                   = "${var.db_name}"
  username                  = "${var.db_name}"
  password                  = "${var.db_password}"
  db_subnet_group_name      = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids    = ["${aws_security_group.allow_tls.id}"]
  skip_final_snapshot       = true
  final_snapshot_identifier = "Ignore"
}

resource "aws_db_parameter_group" "rds_para_grp" {
  name        = "rds-param-group"
  description = "Parameter group for mysql5.6"
  family      = "mysql5.6"
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }
  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}