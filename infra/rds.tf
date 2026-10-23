resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/db-password"
  type  = "SecureString"
  value = random_password.db.result
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "main" {
  identifier                 = "${var.project_name}-db"
  engine                     = "postgres"
  engine_version             = "16"
  instance_class             = "db.t4g.micro"
  allocated_storage          = 20
  storage_type               = "gp3"
  storage_encrypted          = true
  db_name                    = "librarydb"
  username                   = "libraryadmin"
  password                   = random_password.db.result
  port                       = 5432
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  publicly_accessible        = false
  multi_az                   = false
  backup_retention_period    = 0
  skip_final_snapshot        = true
  delete_automated_backups   = true
  deletion_protection        = false
  apply_immediately          = true
  auto_minor_version_upgrade = true
  tags                       = { Name = "${var.project_name}-db" }
}
