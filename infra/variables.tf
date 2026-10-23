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
