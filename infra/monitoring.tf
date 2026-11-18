locals {
  service_dimensions = ["ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name]
  alb_dimensions     = ["LoadBalancer", aws_lb.main.arn_suffix]
  targets_dimensions = concat(local.alb_dimensions, ["TargetGroup", aws_lb_target_group.app.arn_suffix])
  widget_defaults    = { view = "timeSeries", region = var.region, period = 60, stacked = false }
}

resource "aws_cloudwatch_dashboard" "lab2" {
  dashboard_name = "${var.project_name}-lab2"

  dashboard_body = jsonencode({
    periodOverride = "inherit"
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = merge(local.widget_defaults, {
          title = "ECS tasks (desired and running)"
          stat  = "Maximum"
          yAxis = { left = { min = 0, label = "Tasks", showUnits = false } }
          metrics = [
            concat(["ECS/ContainerInsights", "DesiredTaskCount"], local.service_dimensions),
            concat(["ECS/ContainerInsights", "RunningTaskCount"], local.service_dimensions)
          ]
        })
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = merge(local.widget_defaults, {
          title   = "ECS average CPU (%)"
          stat    = "Average"
          yAxis   = { left = { min = 0, max = 100, label = "%", showUnits = false } }
          metrics = [concat(["AWS/ECS", "CPUUtilization"], local.service_dimensions)]
        })
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = merge(local.widget_defaults, {
          title = "ALB requests per minute"
          stat  = "Sum"
          yAxis = { left = { min = 0, label = "Requests/min", showUnits = false } }
          metrics = [
            concat(["AWS/ApplicationELB", "RequestCount"], local.alb_dimensions, [{ label = "All targets" }]),
            concat(["AWS/ApplicationELB", "RequestCountPerTarget"], local.targets_dimensions, [{ label = "Per healthy target" }])
          ]
          annotations = { horizontal = [{ label = "Scaling target (per task)", value = var.requests_per_target }] }
        })
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = merge(local.widget_defaults, {
          title = "ALB target response time p95 (ms)"
          stat  = "p95"
          yAxis = { left = { min = 0, label = "ms", showUnits = false } }
          metrics = [
            concat(["AWS/ApplicationELB", "TargetResponseTime"], local.alb_dimensions, [{ id = "latency", visible = false }]),
            [{ expression = "latency * 1000", label = "p95 (ms)" }]
          ]
        })
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = merge(local.widget_defaults, {
          title = "HTTP 5xx per minute"
          stat  = "Sum"
          yAxis = { left = { min = 0, label = "Responses/min", showUnits = false } }
          metrics = [
            concat(["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count"], local.alb_dimensions, [{ label = "From ECS" }]),
            concat(["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count"], local.alb_dimensions, [{ label = "From ALB" }])
          ]
        })
      }
    ]
  })
}
