variable "enable_scheduled_scaling" {
  type    = bool
  default = false
}

variable "scaling_timezone" {
  type    = string
  default = "Europe/Kyiv"
}

variable "day_scaling_cron" {
  type    = string
  default = "cron(0 7 * * ? *)"
}

variable "night_scaling_cron" {
  type    = string
  default = "cron(0 23 * * ? *)"
}
