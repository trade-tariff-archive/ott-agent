# ott-agent/terraform/redis.tf
resource "aws_security_group" "redis" {
  name   = "ott-agent-redis-${var.environment}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 6379
    to_port         = 6379
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

resource "aws_elasticache_subnet_group" "ott_agent" {
  name       = "ott-agent-${var.environment}"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_elasticache_cluster" "ott_agent" {
  cluster_id           = "ott-agent-${var.environment}"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.ott_agent.name
  security_group_ids   = [aws_security_group.redis.id]
}
