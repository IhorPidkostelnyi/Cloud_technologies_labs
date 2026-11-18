resource "aws_sns_topic" "load" {
  name = "${var.project_name}-load-alerts"
}

resource "aws_sns_topic_subscription" "load_email" {
  topic_arn = aws_sns_topic.load.arn
  protocol  = "email"
  endpoint  = var.alerts_email
}

locals {
  load_alarm_name = "${var.project_name}-maximum-tasks"
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

resource "aws_cloudwatch_metric_alarm" "maximum_tasks" {
  alarm_name          = local.load_alarm_name
  alarm_description   = "The ECS service reached its maximum running task count."
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = local.maximum_tasks
  evaluation_periods  = 1
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
