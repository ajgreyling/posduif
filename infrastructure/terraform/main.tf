terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "posduif" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "posduif-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "posduif" {
  vpc_id = aws_vpc.posduif.id

  tags = {
    Name = "posduif-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.posduif.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "posduif-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.posduif.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.posduif.id
  }

  tags = {
    Name = "posduif-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "posduif" {
  name        = "posduif-sg"
  description = "Security group for Posduif"
  vpc_id      = aws_vpc.posduif.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "PostgreSQL"
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Redis"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "posduif-sg"
  }
}

# Private Subnet for Database
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.posduif.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "posduif-private-subnet"
  }
}

# DB Subnet Group (requires at least 2 subnets in different AZs)
resource "aws_db_subnet_group" "posduif" {
  name       = "posduif-db-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.private.id]

  tags = {
    Name = "posduif-db-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "posduif" {
  identifier             = "posduif-db"
  engine                 = "postgres"
  engine_version         = "16.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage   = 100
  storage_type           = "gp2"
  storage_encrypted       = true
  db_name                = "posduif"
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.posduif.id]
  db_subnet_group_name   = aws_db_subnet_group.posduif.name
  publicly_accessible    = false
  backup_retention_period = 7
  skip_final_snapshot    = false
  final_snapshot_identifier = "posduif-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name = "posduif-db"
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "posduif" {
  name       = "posduif-redis-subnet-group"
  subnet_ids = [aws_subnet.public.id]
}

resource "aws_elasticache_cluster" "posduif" {
  cluster_id           = "posduif-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.posduif.name
  security_group_ids   = [aws_security_group.posduif.id]
}

# EC2 Instance for Sync Engine
resource "aws_instance" "sync_engine" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.posduif.id]
  associate_public_ip_address = true

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    db_endpoint = aws_db_instance.posduif.endpoint
    db_name     = aws_db_instance.posduif.db_name
    db_username = var.db_username
    db_password = var.db_password
    redis_endpoint = aws_elasticache_cluster.posduif.cache_nodes[0].address
  }))

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "posduif-sync-engine"
  }
}

# Elastic IP for Sync Engine
resource "aws_eip" "sync_engine" {
  instance = aws_instance.sync_engine.id
  domain   = "vpc"

  tags = {
    Name = "posduif-sync-engine-eip"
  }
}

