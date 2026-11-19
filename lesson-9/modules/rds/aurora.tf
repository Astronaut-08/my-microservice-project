resource "aws_rds_cluster_parameter_group" "aurora" {
  count       = var.use_aurora ? 1 : 0
  name        = "${var.name}-aurora-params"
  family      = var.parameter_group_family_aurora
  description = "Aurora parameter group for ${var.name}"
  tags        = var.tags
}

resource "aws_rds_cluster" "aurora" {
  count                           = var.use_aurora ? 1 : 0
  cluster_identifier              = var.name
  engine                          = var.engine_cluster
  engine_version                  = var.engine_version_cluster
  database_name                   = var.db_name
  master_username                 = var.username
  master_password                 = var.password
  db_subnet_group_name            = aws_db_subnet_group.default.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora[0].name
  backup_retention_period         = var.backup_retention_period
  port                            = var.db_port
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : var.final_snapshot_identifier
  tags                            = var.tags
}

resource "aws_db_parameter_group" "aurora_instance" {
  count       = var.use_aurora ? 1 : 0
  name        = "${var.name}-aurora-instance-params"
  family      = var.parameter_group_family_aurora
  description = "Aurora instance parameter group for ${var.name}"

  dynamic "parameter" {
    for_each = var.parameters

    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = var.tags
}


resource "aws_rds_cluster_instance" "aurora" {
  count                   = var.use_aurora ? var.aurora_instance_count : 0
  identifier              = "${var.name}-instance-${count.index + 1}"
  cluster_identifier      = aws_rds_cluster.aurora[0].id
  engine                  = var.engine_cluster
  engine_version          = var.engine_version_cluster
  instance_class          = var.instance_class
  tags                    = var.tags
  db_parameter_group_name = aws_db_parameter_group.aurora_instance[0].name
}