locals {
  minimum_tasks = 1
  maximum_tasks = 3
}

resource "aws_appautoscaling_target" "app" {
  min_capacity       = local.minimum_tasks
  max_capacity       = local.maximum_tasks
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "requests" {
  name               = "${var.project_name}-requests-per-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.requests_per_target
    scale_out_cooldown = 60
    scale_in_cooldown  = 180

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
  }
}
