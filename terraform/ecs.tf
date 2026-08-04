# ott-agent/terraform/ecs.tf
resource "aws_security_group" "ecs_task" {
  name   = "ott-agent-task-${var.environment}"
  vpc_id = data.aws_vpc.default.id

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

resource "aws_ecs_cluster" "ott_agent" {
  name = "ott-agent-${var.environment}"
}

resource "aws_cloudwatch_log_group" "ott_agent" {
  name              = "/ecs/ott-agent-${var.environment}"
  retention_in_days = 7
}

locals {
  ecr_image = "${aws_ecr_repository.ott_agent.repository_url}:${var.image_tag}"
}

resource "aws_ecs_task_definition" "ott_agent" {
  family                   = "ott-agent-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "ott-agent"
      image     = local.ecr_image
      essential = true
      portMappings = [{ containerPort = 3000, hostPort = 3000, protocol = "tcp" }]

      environment = [
        { name = "RAILS_ENV",           value = "production" },
        { name = "RAILS_LOG_TO_STDOUT", value = "true" },
        { name = "AWS_REGION",          value = "eu-west-2" },
        { name = "MCP_URL",             value = "https://mcp.trade-tariff.service.gov.uk" },
        { name = "MCP_HUB_TOKEN_URL",   value = "https://auth.id.trade-tariff.service.gov.uk/oauth2/token" },
        { name = "DB_HOST",             value = aws_db_instance.ott_agent.address },
        { name = "DB_NAME",             value = aws_db_instance.ott_agent.db_name },
        { name = "DB_USERNAME",         value = aws_db_instance.ott_agent.username },
        { name = "REDIS_URL",           value = "redis://${aws_elasticache_cluster.ott_agent.cache_nodes[0].address}:6379/0" }
      ]

      secrets = [
        { name = "SECRET_KEY_BASE",   valueFrom = data.aws_ssm_parameter.secret_key_base.arn },
        { name = "MCP_CLIENT_ID",     valueFrom = data.aws_ssm_parameter.mcp_client_id.arn },
        { name = "MCP_CLIENT_SECRET", valueFrom = data.aws_ssm_parameter.mcp_client_secret.arn },
        { name = "DB_PASSWORD",       valueFrom = aws_ssm_parameter.db_password.arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ott_agent.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ott-agent"
        }
      }
    },
    {
      name      = "sidekiq"
      image     = local.ecr_image
      essential = false
      command   = ["bundle", "exec", "sidekiq"]

      environment = [
        { name = "RAILS_ENV",           value = "production" },
        { name = "RAILS_LOG_TO_STDOUT", value = "true" },
        { name = "AWS_REGION",          value = "eu-west-2" },
        { name = "MCP_URL",             value = "https://mcp.trade-tariff.service.gov.uk" },
        { name = "MCP_HUB_TOKEN_URL",   value = "https://auth.id.trade-tariff.service.gov.uk/oauth2/token" },
        { name = "DB_HOST",             value = aws_db_instance.ott_agent.address },
        { name = "DB_NAME",             value = aws_db_instance.ott_agent.db_name },
        { name = "DB_USERNAME",         value = aws_db_instance.ott_agent.username },
        { name = "REDIS_URL",           value = "redis://${aws_elasticache_cluster.ott_agent.cache_nodes[0].address}:6379/0" }
      ]

      secrets = [
        { name = "SECRET_KEY_BASE",   valueFrom = data.aws_ssm_parameter.secret_key_base.arn },
        { name = "MCP_CLIENT_ID",     valueFrom = data.aws_ssm_parameter.mcp_client_id.arn },
        { name = "MCP_CLIENT_SECRET", valueFrom = data.aws_ssm_parameter.mcp_client_secret.arn },
        { name = "DB_PASSWORD",       valueFrom = aws_ssm_parameter.db_password.arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ott_agent.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "sidekiq"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "ott_agent" {
  name            = "ott-agent-${var.environment}"
  cluster         = aws_ecs_cluster.ott_agent.id
  task_definition = aws_ecs_task_definition.ott_agent.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_task.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ott_agent.arn
    container_name   = "ott-agent"
    container_port   = 3000
  }
}
