
locals {
  region = "ap-southeast-2"
  #name   = "dms-ex-${replace(basename(path.cwd), "_", "-")}"
  name   = "dms-pgres-to-snowflake"

  db_name     = "example"
  db_username = "example"

  # aws dms describe-event-categories
  replication_instance_event_categories = ["failure", "creation", "deletion", "maintenance", "failover", "low storage", "configuration change"]
  replication_task_event_categories     = ["failure", "state change", "creation", "deletion", "configuration change"]

  bucket_postfix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  bucket_name    = "${local.name}-s3-${local.bucket_postfix}"

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/oquaglio/terraform-dms-postgres-to-s3"
  }
}

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# DMS Module
################################################################################

# module "dms_disabled" {
#   source  = "terraform-aws-modules/dms/aws"
#   version = "~> 1.0"

#   create = false
# }

# module "dms_default" {
#   source  = "terraform-aws-modules/dms/aws"
#   version = "~> 1.0"

#   # Note - if enabled, this will by default only create
#   # - DMS necessary IAM roles
#   # - Subnet group
#   # - Replication instance
#   create = false # not enabling by default to avoid messing with the IAM roles

#   # Subnet group
#   repl_subnet_group_name        = local.name
#   repl_subnet_group_description = "DMS Subnet group for ${local.name}"
#   #repl_subnet_group_subnet_ids  = module.vpc.database_subnets

#   # Instance
#   repl_instance_class = "dms.t3.large"
#   repl_instance_id    = local.name

#   tags = local.tags
# }

# resource "aws_db_instance" "my_database_name" {
#   identifier        = "my-database-name"
#   allocated_storage = 100
#   instance_class    = "db.m4.large"

#   engine         = "postgres"
#   engine_version = "10.6"
#   name           = "<my_database_name>"
#   username       = "postgres"
#   password       = "<my_database_password>"

#   vpc_security_group_ids = [aws_security_group.my_database_name.id]
#   db_subnet_group_name   = aws_db_subnet_group.my_database_name.name

#   multi_az                = true
#   storage_type            = "gp2"
#   backup_retention_period = 6
#   storage_encrypted       = true

#   skip_final_snapshot       = false
#   final_snapshot_identifier = "final-snapshot-my-database-name"
# }

################################################################################
# Supporting Modules
################################################################################

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.1"

  bucket = local.bucket_name

  attach_deny_insecure_transport_policy = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}
