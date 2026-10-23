output "app_url" {
  value = "http://${aws_lb.main.dns_name}"
}
output "aws_region" {
  value = var.region
}
output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
output "ecr_repository_name" {
  value = aws_ecr_repository.app.name
}
output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}
output "ecs_service_name" {
  value = aws_ecs_service.app.name
}
output "github_actions_role_arn" {
  value = var.enable_github_actions ? aws_iam_role.github[0].arn : null
}
output "rds_identifier" {
  value = aws_db_instance.main.identifier
}
output "db_security_group_id" {
  value = aws_security_group.db.id
}
output "app_security_group_id" {
  value = aws_security_group.app.id
}
output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}
