terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "email" {
  type        = string
  description = "Email address for cost notifications"

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", var.email))
    error_message = "Enter a valid email address."
  }
}

resource "aws_budgets_budget" "lab" {
  name         = "cloud-lab1-ihor-budget"
  budget_type  = "COST"
  limit_amount = "5"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit = false
    include_refund = false
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 1
    threshold_type            = "ABSOLUTE_VALUE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 5
    threshold_type            = "ABSOLUTE_VALUE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget.arn]
  }

  depends_on = [aws_sns_topic_policy.budget]
}

output "budget_name" {
  value = aws_budgets_budget.lab.name
}