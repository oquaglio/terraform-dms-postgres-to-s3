resource "random_pet" "this" {
  length = 2
}


# Role to allow DMS Service to access bucket
resource "aws_iam_role" "s3_role" {
  name        = "${var.stack_name}-s3-role"
  description = "Role used to migrate data from S3 via DMS"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DMSAssume"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.${data.aws_partition.current.dns_suffix}"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.stack_name}-s3-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "DMSAllAccess"
          Action   = ["s3:*"]
          Effect   = "Allow"
          Resource = "${module.s3_bucket.s3_bucket_arn}/*"
        },
        {
          Sid      = "DMSListAccess"
          Action   = ["s3:ListBucket"]
          Effect   = "Allow"
          Resource = module.s3_bucket.s3_bucket_arn
        },
      ]
    })
  }

  tags = local.tags
}


################################################################################
# Source Database
################################################################################

resource "aws_db_instance" "source" {
  identifier              = "${var.stack_name}-${var.environment}-${var.source_db_identifier}-source"
  parameter_group_name    = aws_db_parameter_group.source-pg.name
  publicly_accessible     = true
  allocated_storage       = var.source_storage
  engine                  = var.source_engine
  engine_version          = var.source_engine_version
  instance_class          = var.source_instance_class
  db_name                 = var.source_db_name
  username                = var.source_username
  password                = var.source_password
  multi_az                = var.source_rds_is_multi_az
  db_subnet_group_name    = module.vpc.database_subnet_group
  backup_retention_period = var.source_backup_retention_period
  backup_window           = var.source_backup_window
  maintenance_window      = var.source_maintenance_window
  storage_encrypted       = var.source_storage_encrypted
  # only for dev/test builds
  skip_final_snapshot = true

}

resource "aws_db_parameter_group" "source-pg" {
  family = "postgres13"
  name   = "${var.stack_name}-postgres13-pg"
  parameter {
    apply_method = "pending-reboot"
    name         = "rds.logical_replication"
    value        = "1"
  }
  parameter {
    apply_method = "immediate"
    name         = "wal_sender_timeout"
    value        = "0"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pglogical"
  }

}


################################################################################
# Terraform Resources
################################################################################

resource "snowflake_warehouse" "warehouse" {
  name           = var.snowflake_warehouse
  warehouse_size = var.snowflake_warehouse_size

  auto_suspend = 60
}
