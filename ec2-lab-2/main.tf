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

# Provides secrets manager to store the db_password
resource "aws_secretsmanager_secret" "peex" {
  name = "peex"
}

resource "aws_secretsmanager_secret_version" "peex" {
  secret_id     = aws_secretsmanager_secret.peex.id
  secret_string = jsonencode(var.db_password)
}

# Provides private subnet 1 for the RDS
resource "aws_subnet" "private-subnet1" {
vpc_id = "${aws_vpc.main.id}"
cidr_block = "192.168.1.0/24"
availability_zone = "us-east-1a"
}

# Provides private subnet 2 for the RDS
resource "aws_subnet" "private-subnet2" {
vpc_id = "${aws_vpc.main.id}"
cidr_block = "192.168.2.0/24"
availability_zone = "us-east-1b"
}

# Provides the DB subnet
resource "aws_db_subnet_group" "db-subnet" {
name = "db subnet group"
subnet_ids = ["${aws_subnet.private-subnet1.id}", "${aws_subnet.private-subnet2.id}"] 
}

# Provides the RDS instance
resource "aws_db_instance" "rds_instance" {
  identifier                = "${var.rds_instance_identifier}"
  allocated_storage         = 5
  engine                    = "mysql"
  engine_version            = "5.6.35"
  instance_class            = "db.t2.micro"
  db_name                   = "${var.db_name}"
  username                  = "${var.db_name}"
  password                  = "${aws_secretsmanager_secret.peex.id}"
  db_subnet_group_name      = "${aws_db_subnet_group.db-subnet.id}"
  vpc_security_group_ids    = ["${aws_security_group.allow_tls.id}"]
  skip_final_snapshot       = true
  final_snapshot_identifier = "Ignore"
}

# Provides the RDS instance parameter group
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

# Provides S3 bucket
resource "aws_s3_bucket" "peex" {
  bucket = "my-tf-peex-bucket"

  tags = {
    Name        = "Peex bucket"
    Environment = "Dev"
  }
}

# Provides S3 bucket ACL
resource "aws_s3_bucket_acl" "peex" {
  bucket = aws_s3_bucket.peex.id
  acl    = "aws-exec-read"
}

# Provides S3 bucket versioning to be enabled
resource "aws_s3_bucket_versioning" "peex" {
  bucket = aws_s3_bucket.peex.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Provides S3 bucket archiving and backup
resource "aws_s3_bucket_lifecycle_configuration" "peex" {
  bucket = aws_s3_bucket.peex.id

  rule {
    id = "log"

    expiration {
      days = 90
    }

    filter {
      and {
        prefix = "log/"

        tags = {
          rule      = "log"
          autoclean = "true"
        }
      }
    }

    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }

  rule {
    id = "tmp"

    filter {
      prefix = "tmp/"
    }

    expiration {
      date = "2023-06-13T00:00:00Z"
    }

    status = "Enabled"
  }
}

# Provides in-memory service
resource "aws_elasticache_cluster" "peex" {
  cluster_id           = "cluster-peex"
  engine               = "redis"
  node_type            = "cache.m4.large"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis3.2"
  engine_version       = "3.2.10"
  port                 = 6379
}