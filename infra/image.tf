locals {
  app_path = abspath("${path.module}/../app")
  app_hash = sha256(join("", [
    for filename in sort(tolist(fileset(local.app_path, "*"))) :
    filesha256("${local.app_path}/${filename}")
  ]))
  initial_tag = "initial-${substr(local.app_hash, 0, 16)}"
}

data "aws_ecr_authorization_token" "initial" {}

resource "docker_image" "initial" {
  name         = "${aws_ecr_repository.app.repository_url}:${local.initial_tag}"
  keep_locally = true
  build {
    context  = local.app_path
    platform = "linux/amd64"
    build_args = {
      APP_REVISION = local.initial_tag
    }
  }
}

resource "docker_registry_image" "initial" {
  name          = docker_image.initial.name
  keep_remotely = true
  auth_config {
    address  = split("/", aws_ecr_repository.app.repository_url)[0]
    username = data.aws_ecr_authorization_token.initial.user_name
    password = data.aws_ecr_authorization_token.initial.password
  }
  triggers = {
    image_id = docker_image.initial.image_id
  }
}
