locals {
  minimum_tasks = 1
  maximum_tasks = 3
  scheduled_minimums = {
    day   = { minimum = 2, schedule = var.day_scaling_cron }
    night = { minimum = 1, schedule = var.night_scaling_cron }
  }
}

resource "aws_appautoscaling_target" "app" {
  min_capacity       = local.minimum_tasks
  max_capacity       = local.maximum_tasks
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = [min_capacity]
  }
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project_name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.scaling_cpu_target
    scale_out_cooldown = 60
    scale_in_cooldown  = 180

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_scheduled_action" "minimum" {
  for_each = var.enable_scheduled_scaling ? local.scheduled_minimums : {}

  name               = "${var.project_name}-${each.key}"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace
  schedule           = each.value.schedule
  timezone           = var.scaling_timezone

  scalable_target_action {
    min_capacity = each.value.minimum
    max_capacity = local.maximum_tasks
  }
}
