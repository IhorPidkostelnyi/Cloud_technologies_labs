resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 1
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name         = "app"
    image        = "${aws_ecr_repository.app.repository_url}:${local.initial_tag}"
    essential    = true
    portMappings = [{ containerPort = 8000, protocol = "tcp" }]
    environment = [
      { name = "DB_HOST", value = aws_db_instance.main.address },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_NAME", value = aws_db_instance.main.db_name },
      { name = "DB_USER", value = "libraryadmin" },
      { name = "DB_SSLMODE", value = "require" }
    ]
    secrets = [{ name = "DB_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
  depends_on = [docker_registry_image.initial]
}

resource "aws_ecs_service" "app" {
  name                               = "${var.project_name}-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  wait_for_steady_state              = true
  health_check_grace_period_seconds  = 180
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8000
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
  depends_on = [
    aws_lb_listener.http,
    aws_route_table_association.app,
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.ssm,
    aws_vpc_security_group_ingress_rule.app_from_alb,
    aws_vpc_security_group_ingress_rule.db_from_app,
    aws_vpc_security_group_egress_rule.app_to_db,
    aws_vpc_security_group_egress_rule.app_https,
    aws_vpc_security_group_egress_rule.alb_to_app,
    aws_vpc_security_group_ingress_rule.http
  ]
}
