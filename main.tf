
locals {
  #region = "ap-southeast-2"
  #name   = "dms-ex-${replace(basename(path.cwd), "_", "-")}"
  #name   = "dms-pgres-to-snowflake"

  #db_name     = "oq-rds-postgres-1"
  db_username = "postgres"
  count       = length(var.availability_zones)

  # aws dms describe-event-categories
  replication_instance_event_categories = ["failure", "creation", "deletion", "maintenance", "failover", "low storage", "configuration change"]
  replication_task_event_categories     = ["failure", "state change", "creation", "deletion", "configuration change"]

  bucket_postfix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  bucket_name    = "${var.stack_name}-s3-${local.bucket_postfix}"

  tags = {
    stack_name  = "${var.stack_name}"
    environment = "${var.environment}"
    repository  = "https://github.com/oquaglio/terraform-dms-postgres-to-s3"
    created_by  = "terraform"
  }
}



################################################################################
# DMS Module
################################################################################

# module "dms_disabled" {
#   source  = "terraform-aws-modules/dms/aws"
#   version = "~> 1.0"

#   create = false
# }

module "dms" {
  source  = "terraform-aws-modules/dms/aws"
  version = "~> 1.0"

  # Note - if enabled, this will by default only create
  # - DMS necessary IAM roles
  # - Subnet group
  # - Replication instance
  create = true # not enabling by default to avoid messing with the IAM roles

  # Subnet group
  repl_subnet_group_name        = var.stack_name
  repl_subnet_group_description = "DMS Subnet group for ${var.stack_name}"
  repl_subnet_group_subnet_ids  = module.vpc.database_subnets

  # Instance
  repl_instance_class = "dms.t3.micro"
  repl_instance_id    = var.stack_name

  endpoints = {
    postgresql-source = {
      database_name = "${var.source_db_name}"
      endpoint_id   = "${var.stack_name}-postgres-source"
      endpoint_type = "source"
      engine_name   = "postgres"
      server_name   = "${data.aws_db_instance.source_database.address}"
      port          = "${var.source_db_port}"
      username      = "${var.source_username}"
      password      = "${var.source_password}"
      ssl_mode      = "none"
      tags = {
        EndpointType = "postgresql-source"
        stack_name   = "${var.stack_name}"
        environment  = "${var.environment}"
        created_by   = "terraform"
      }
    }

    s3-destination = {
      endpoint_id   = "${var.stack_name}-s3-destination"
      endpoint_type = "target"
      engine_name   = "s3"
      ssl_mode      = "none"

      s3_settings = {
        bucket_folder           = "destinationdata"
        bucket_name             = local.bucket_name # to avoid https://github.com/hashicorp/terraform/issues/4149
        data_format             = "parquet"
        encryption_mode         = "SSE_S3"
        service_access_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.stack_name}-s3-role" # to avoid https://github.com/hashicorp/terraform/issues/4149
      }

      tags = {
        EndpointType = "s3-destination"
        stack_name   = "${var.stack_name}"
        environment  = "${var.environment}"
        created_by   = "terraform"
      }

    }
  }

  tags = local.tags
}

# Create an endpoint for the source database

# resource "aws_dms_endpoint" "source" {
#   database_name = "${var.source_db_name}"
#   endpoint_id   = "${var.stack_name}-dms-${var.environment}-source"
#   endpoint_type = "source"
#   engine_name   = "${var.source_engine_name}"
#   password      = "${var.source_app_password}"
#   port          = "${var.source_db_port}"
#   server_name   = "${aws_db_instance.source.address}"
#   ssl_mode      = "none"
#   username      = "${var.source_app_username}"

#   tags {
#     Name        = "${var.stack_name}-dms-${var.environment}-source"
#     owner       = "${var.owner}"
#     stack_name  = "${var.stack_name}"
#     environment = "${var.environment}"
#     created_by  = "terraform"
#   }
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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.stack_name
  cidr = "10.99.0.0/18"

  azs              = ["${var.availability_zones[0]}", "${var.availability_zones[1]}", "${var.availability_zones[2]}"] # careful on which AZs support DMS VPC endpoint
  public_subnets   = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets  = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  database_subnets = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]

  create_database_subnet_group = true
  enable_nat_gateway           = false # not required, using private VPC endpoint
  single_nat_gateway           = true
  map_public_ip_on_launch      = false

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                      = true
  flow_log_destination_type            = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60
  flow_log_log_format                  = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id}"

  enable_dhcp_options      = true
  enable_dns_hostnames     = true
  dhcp_options_domain_name = data.aws_region.current.name == "us-east-1" ? "ec2.internal" : "${data.aws_region.current.name}.compute.internal"

  tags = local.tags
}

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
