terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "azs" {
  default = ["us-east-1a", "us-east-1b"]
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "ror-vpc" }
}

# Public Subnets (for ALB)
resource "aws_subnet" "public_alb" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, 100 + count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "ror-public-alb-${count.index}" }
}

# Private Subnets (for ECS, RDS)
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false
  tags = { Name = "ror-private-${count.index}" }
}

# Internet Gateway (for ALB)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_alb" {
  count          = 2
  subnet_id      = aws_subnet.public_alb[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway (for private subnet internet access)
resource "aws_eip" "nat" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_alb[0].id
  depends_on    = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# S3 Bucket
resource "aws_s3_bucket" "app" {
  bucket        = "ror-app-bucket-fixed"
  force_destroy = true
}

# ECR
data "aws_ecr_repository" "app" {
  name = "ror-app-repo"
}

# RDS (Private Subnets)
resource "aws_db_subnet_group" "default" {
  name       = "ror-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "postgres" {
  identifier              = "ror-db"
  engine                  = "postgres"
  engine_version          = "13.15"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "rorappdb"
  username                = "roruser"
  password                = "securepassword"
  skip_final_snapshot     = true
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.default.name
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Allow HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name   = "rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role
resource "aws_iam_role" "ecs_exec" {
  name = "ecs-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "ecs-s3-access"
  role = aws_iam_role.ecs_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["s3:*"],
      Resource = [
        aws_s3_bucket.app.arn,
        "${aws_s3_bucket.app.arn}/*"
      ]
    }]
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "ror-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "ror-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([{
    name      = "ror-container",
    image     = "${data.aws_ecr_repository.app.repository_url}:v1.0.0",
    essential = true,
    portMappings = [{
      containerPort = 3000
    }],
    environment = [
      { name = "RDS_DB_NAME",     value = aws_db_instance.postgres.db_name },
      { name = "RDS_USERNAME",    value = aws_db_instance.postgres.username },
      { name = "RDS_PASSWORD",    value = "securepassword" },
      { name = "RDS_HOSTNAME",    value = aws_db_instance.postgres.address },
      { name = "RDS_PORT",        value = tostring(aws_db_instance.postgres.port) },
      { name = "S3_BUCKET_NAME",  value = aws_s3_bucket.app.bucket },
      { name = "S3_REGION_NAME",  value = var.aws_region },
      { name = "LB_ENDPOINT",     value = aws_lb.app.dns_name }
    ]
  }])
}

# Load Balancer
resource "aws_lb" "app" {
  name               = "ror-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public_alb[*].id
}

resource "aws_lb_target_group" "app" {
  name        = "ror-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "ror-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "ror-container"
    container_port   = 3000
  }
  depends_on = [aws_lb_listener.http]
}

# Output
output "load_balancer_dns" {
  description = "DNS of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}
