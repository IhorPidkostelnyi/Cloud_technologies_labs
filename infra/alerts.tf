resource "aws_sns_topic" "load" {
  name = "${var.project_name}-load-alerts"
}

resource "aws_sns_topic_subscription" "load_email" {
  topic_arn = aws_sns_topic.load.arn
  protocol  = "email"
  endpoint  = var.alerts_email
}

locals {
  load_alarm_name = "${var.project_name}-cpu-high"
  load_cpu_limit  = 70
}

resource "aws_sns_topic_policy" "load" {
  arn = aws_sns_topic.load.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.load.arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnEquals = {
          "aws:SourceArn" = "arn:aws:cloudwatch:${var.region}:${data.aws_caller_identity.current.account_id}:alarm:${local.load_alarm_name}"
        }
      }
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = local.load_alarm_name
  alarm_description   = "ECS service average CPU exceeded 70 percent for two minutes."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = local.load_cpu_limit
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  period              = 60
  treat_missing_data  = "missing"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.load.arn]
  ok_actions    = [aws_sns_topic.load.arn]

  depends_on = [aws_sns_topic_policy.load]
}
