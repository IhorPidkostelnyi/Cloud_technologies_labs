variable "region" {
  type    = string
  default = "eu-north-1"
}
variable "enable_github_actions" {
  type        = bool
  default     = false
  description = "Enable GitHub OIDC only in an AWS account whose organization policy permits it."
}
variable "project_name" {
  type    = string
  default = "cloud-lab1-ihor"
}
variable "github_repository" {
  type    = string
  default = "IhorPidkostelnyi/Cloud_technologies_labs"
}
variable "github_owner_id" {
  type    = string
  default = "182145211"
}
variable "github_repository_id" {
  type    = string
  default = "1424722125"
}

variable "scaling_cpu_target" {
  type        = number
  default     = 60
  description = "Target average ECS CPU utilization in percent."

  validation {
    condition     = var.scaling_cpu_target > 0 && var.scaling_cpu_target < 100
    error_message = "scaling_cpu_target must be between 0 and 100 percent."
  }
}

variable "books_cache_enabled" {
  type    = bool
  default = false
}

variable "alerts_email" {
  type        = string
  sensitive   = true
  description = "Email address for load alerts."

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", var.alerts_email))
    error_message = "Enter a valid email address."
  }
}
