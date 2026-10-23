resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  encryption_configuration {
    encryption_type = "AES256"
  }
}
