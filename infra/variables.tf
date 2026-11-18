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

variable "requests_per_target" {
  type        = number
  default     = 300
  description = "Target application requests per minute per healthy ECS task."

  validation {
    condition     = var.requests_per_target > 0
    error_message = "requests_per_target must be greater than zero."
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
