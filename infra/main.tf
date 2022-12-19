
locals {
  #region = "ap-southeast-2"
  #name   = "dms-ex-${replace(basename(path.cwd), "_", "-")}"
  #name   = "dms-pgres-to-snowflake"

  #db_name     = "oq-rds-postgres-1"
  db_username = var.source_username
  count       = length(var.availability_zones)

  # aws dms describe-event-categories
  replication_instance_event_categories = ["failure", "creation", "deletion", "maintenance", "failover", "low storage", "configuration change"]
  replication_task_event_categories     = ["failure", "state change", "creation", "deletion", "configuration change"]

  bucket_postfix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  bucket_name    = "${var.stack_name}-s3-${var.environment}-${local.bucket_postfix}"

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
      endpoint_id   = "${var.stack_name}-${var.environment}-${var.source_db_identifier}-source"
      endpoint_type = "source"
      engine_name   = "${var.source_engine}"
      server_name   = "${aws_db_instance.source.address}"
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
      endpoint_id   = local.bucket_name
      endpoint_type = "target"
      engine_name   = "s3"
      ssl_mode      = "none"

      s3_settings = {
        bucket_folder           = "destinationdata"
        bucket_name             = local.bucket_name # to avoid https://github.com/hashicorp/terraform/issues/4149
        data_format             = "parquet"
        parquet_version         = "parquet-2-0"
        timestamp_column_name   = "dms_timestamp"
        compression_type        = "GZIP"
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

  replication_tasks = {
    postgres_s3 = {
      replication_task_id       = "${var.stack_name}-postgres-to-s3"
      migration_type            = "full-load-and-cdc"
      replication_task_settings = file("configs/task_settings.json")
      table_mappings            = file("configs/table_mappings.json")
      source_endpoint_key       = "postgresql-source"
      target_endpoint_key       = "s3-destination"
      tags                      = { Task = "PostgreSQL-to-S3" }
    }
  }

  tags = local.tags
}


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

  manage_default_security_group = true
  default_security_group_ingress = [
    { self = true },
    {
      description      = "Allow all ingress traffic"
      from_port        = 0
      to_port          = 0
      protocal         = "-1"
      cidr_blocks      = "0.0.0.0/0"
      ipv6_cidr_blocks = ""
      security_groups  = ""
    }
  ]
  default_security_group_egress = [{ self = true }]

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


module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 3.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc_endpoint_security_group.security_group_id]

  endpoints = {
    dms = {
      service             = "dms"
      private_dns_enabled = true
      subnet_ids          = [element(module.vpc.database_subnets, 0), element(module.vpc.database_subnets, 1)] # careful on which AZs support DMS VPC endpoint
      tags                = { Name = "dms-vpc-endpoint" }
    }
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.private_route_table_ids, module.vpc.database_route_table_ids])
      tags            = { Name = "s3-vpc-endpoint" }
    }
    secretsmanager = {
      service_name = "com.amazonaws.${var.region}.secretsmanager"
      subnet_ids   = module.vpc.database_subnets
    }
  }

  tags = local.tags
}

module "vpc_endpoint_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.stack_name}-vpc-endpoint"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "VPC Endpoints HTTPs for the VPC CIDR"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]

  egress_cidr_blocks = [module.vpc.vpc_cidr_block]
  egress_rules       = ["all-all"]

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  # Creates multiple
  for_each = {
    postgresql-source    = ["postgresql-tcp"]
    mysql-destination    = ["mysql-tcp"]
    replication-instance = ["postgresql-tcp", "mysql-tcp", "kafka-broker-tls-tcp"]
    kafka-destination    = ["kafka-broker-tls-tcp"]
  }

  name        = "${var.stack_name}-${each.key}"
  description = "Security group for ${each.key}"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = module.vpc.database_subnets_cidr_blocks
  ingress_rules       = each.value

  egress_cidr_blocks = [module.vpc.vpc_cidr_block]
  egress_rules       = ["all-all"]

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
