provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1b"]
  }
}

resource "aws_security_group" "rds" {
  name   = "videoclub-rds-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.cluster_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "videoclub-rds-sg"
  }
}

resource "aws_db_instance" "videoclub" {
  identifier              = var.rds_identifier
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 0
  vpc_security_group_ids  = [aws_security_group.rds.id]

  tags = {
    Name = var.rds_identifier
  }
}

resource "aws_sqs_queue" "rating_requests" {
  name                       = var.sqs_queue_name
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30

  tags = {
    Name = var.sqs_queue_name
  }
}

resource "aws_secretsmanager_secret" "rds" {
  name                    = "videoclub/rds/credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    host     = aws_db_instance.videoclub.address
    port     = 5432
    dbname   = var.db_name
    username = var.db_username
    password = var.db_password
  })
}
