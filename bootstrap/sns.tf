provider "aws" {
  alias  = "alerts"
  region = "eu-north-1"
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "budget" {
  provider = aws.alerts
  name     = "cloud-lab1-ihor-budget-alerts"
}

resource "aws_sns_topic_policy" "budget" {
  provider = aws.alerts
  arn      = aws_sns_topic.budget.arn

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Sid       = "AllowBudgetsPublish"
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.budget.arn

      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }

        ArnLike = {
          "aws:SourceArn" = "arn:aws:budgets::${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "email" {
  provider  = aws.alerts
  topic_arn = aws_sns_topic.budget.arn
  protocol  = "email"
  endpoint  = var.email
}

output "budget_sns_topic_arn" {
  value = aws_sns_topic.budget.arn
}