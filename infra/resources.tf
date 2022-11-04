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
# Snowflake Resources
################################################################################

locals {
  role_name = "snowflake-integration-object-role"
  role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.role_name}"
}

# Storage integration object
# Note: the arn for the IAM role is pre-calculated to get around
# the apparent circular dependency
resource "snowflake_storage_integration" "snowflake_int_obj" {
  name    = "S3_INT_AWS_RDS"
  comment = "Storage integration for RDS data loading from AWS"
  type    = "EXTERNAL_STAGE"

  enabled = true

  storage_allowed_locations = ["s3://${local.bucket_name}/"]
  #   storage_blocked_locations = [""]
  #   storage_aws_object_acl    = "bucket-owner-full-control"

  storage_provider = "S3"
  #storage_aws_external_id  = "..."
  #storage_aws_iam_user_arn = "..."
  storage_aws_role_arn = local.role_arn
}

#
# Role to allow integration object access to the S3 bucket
resource "aws_iam_role" "iam-int-obj-role" {
  name = local.role_name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : snowflake_storage_integration.snowflake_int_obj.storage_aws_iam_user_arn
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {
          "StringEquals" : {
            "sts:ExternalId" : snowflake_storage_integration.snowflake_int_obj.storage_aws_external_id
          }
        }
      }
    ]
  })

  tags = local.tags
}


resource "snowflake_warehouse" "warehouse" {
  name           = var.snowflake_warehouse
  warehouse_size = var.snowflake_warehouse_size

  auto_suspend = 60
}

resource "snowflake_file_format" "parquet_file_format" {
  name        = "PARQUET_FILE_FORMAT"
  database    = "DEV"
  schema      = "RAW"
  format_type = "PARQUET"
  compression = "AUTO"
}

resource "snowflake_stage" "s3_stage" {
  name                = "S3_STAGE"
  url                 = "s3://${local.bucket_name}/"
  database            = "DEV"
  schema              = "RAW"
  storage_integration = snowflake_storage_integration.snowflake_int_obj.name
  file_format         = "FORMAT_NAME = DEV.RAW.PARQUET_FILE_FORMAT"
}

resource "snowflake_pipe" "movie_pipe" {
  database = "DEV"
  schema   = "RAW"
  name     = "movie_pipe"

  comment = "Pipe for loading movie data."

  copy_statement = "COPY INTO DEV.RAW.MOVIE (ID, TITLE, YEAR, RATING, SOURCE) FROM (SELECT t.$1:id::INTEGER as id, t.$1:title::VARCHAR as title, t.$1:year::INTEGER as year, t.$1:rating::DECIMAL(3,1) as rating, 'DU Stack' as source FROM @DEV.RAW.S3_STAGE/destinationdata/movie as t);"
  auto_ingest    = true
}
