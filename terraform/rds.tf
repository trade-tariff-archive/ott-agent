# ott-agent/terraform/rds.tf
resource "aws_security_group" "rds" {
  name        = "ott-agent-rds-${var.environment}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_task.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "ott_agent" {
  name       = "ott-agent-${var.environment}"
  subnet_ids = data.aws_subnets.default.ids
}

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/ott-agent/${var.environment}/DB_PASSWORD"
  type  = "SecureString"
  value = random_password.db_password.result
}

resource "aws_db_instance" "ott_agent" {
  identifier             = "ott-agent-${var.environment}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "ott_agent_${var.environment}"
  username               = "ott_agent"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.ott_agent.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  deletion_protection    = false
  publicly_accessible    = false
}
