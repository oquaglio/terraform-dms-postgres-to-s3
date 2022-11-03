#--------------------------------------------------------------
# Global Config
#--------------------------------------------------------------

# Variables used in the global config

variable "region" {
  description = "The AWS region we want to build this stack in"
  default     = "ap-southeast-2"
}

variable "availability_zones" {
  description = "Geographically distanced areas inside the region"

  default = {
    "0" = "ap-southeast-2a"
    "1" = "ap-southeast-2b"
    "2" = "ap-southeast-2c"
  }
}

variable "stack_name" {
  description = "The name of our application"
  default     = "dms-postgres-stack"
}

variable "owner" {
  description = "A group email address to be used in tags"
  default     = "test@email.com"
}

variable "environment" {
  description = "Used for seperating terraform backends and naming items"
  default     = "dev"
}


#--------------------------------------------------------------
# DMS source config
#--------------------------------------------------------------


# variable "source_db_identifier" {
#   default     = "rds-postgres"
#   description = "RDS DB Identiifer"
# }

# variable "source_db_name" {
#   default     = "postgres"
#   description = "Name of the database in the RDS"
# }

# variable "source_db_port" {
#   description = "The port the Application Server will access the database on"
#   default     = 5432
# }

# variable "source_username" {
#   description = "Username to access the source database"
#}

# variable "source_password" {
#   description = "Password of the source database"
# }


#--------------------------------------------------------------
# DMS Replication Instance
#--------------------------------------------------------------

variable "replication_instance_maintenance_window" {
  description = "Maintenance window for the replication instance"
  default     = "sun:10:30-sun:14:30"
}

variable "replication_instance_storage" {
  description = "Size of the replication instance in GB"
  default     = "10"
}

variable "replication_instance_version" {
  description = "Engine version of the replication instance"
  default     = "1.9.0"
}

variable "replication_instance_class" {
  description = "Instance class of replication instance"
  default     = "dms.t2.micro"
}


#--------------------------------------------------------------
# RDS config (DMS source)
#--------------------------------------------------------------

variable "source_db_identifier" {
  default     = "rds-postgres"
  description = "RDS DB Identiifer"
}

# variable "source_app_password" {
#   description = "Password for the endpoint to access the source database"
# }

# variable "source_app_username" {
#   description = "Username for the endpoint to access the source database"
# }

variable "source_backup_retention_period" {
  # Days
  default     = "1"
  description = "Retention of RDS backups"
}

variable "source_backup_window" {
  # 12:00AM-03:00AM AEST
  default     = "14:00-17:00"
  description = "RDS backup window"
}

#  DBName must begin with a letter and contain only alphanumeric characters.
variable "source_db_name" {
  description = "Name of the database in the RDS instance"
  default     = "postgresdb"
}

variable "source_db_port" {
  description = "The port the Application Server will access the database on"
  default     = 5432
}

variable "source_engine" {
  default     = "postgres"
  description = "Engine type, example values mysql, postgres"
}

# variable "source_engine_name" {
#   default     = "oracle"
#   description = "Engine name for DMS"
# }

variable "source_engine_version" {
  description = "Engine version"
  default     = "13.7"
}

variable "source_instance_class" {
  default     = "db.t3.micro"
  description = "Instance class"
}

variable "source_maintenance_window" {
  default     = "Mon:00:00-Mon:03:00"
  description = "RDS maintenance window"
}

variable "source_password" {
  description = "Password of the source database"
}

variable "source_rds_is_multi_az" {
  description = "Create backup database in separate availability zone"
  default     = "false"
}

# variable "source_snapshot" {
#   description = "Snapshot ID"
# }

variable "source_storage" {
  default     = "10"
  description = "Storage size in GB"
}

variable "source_storage_encrypted" {
  description = "Encrypt storage or leave unencrypted"
  default     = false
}

variable "source_username" {
  description = "Username to access the source database"
}



#--------------------------------------------------------------
# Network
#--------------------------------------------------------------

variable "database_subnet_cidr" {
  default     = ["10.0.0.0/26", "10.0.0.64/26", "10.0.0.128/26"]
  description = "List of subnets to be used for databases"
}

variable "vpc_cidr" {
  description = "CIDR for the whole VPC"
  default     = "10.0.0.0/24"
}


#--------------------------------------------------------------
# Snowflake
#
# Override using cmd line args or .tfvars file
#--------------------------------------------------------------

variable "snowflake_user" {
  description = ""
}

variable "snowflake_role" {
  description = ""
}

variable "snowflake_private_key_path" {
  description = ""
}

variable "snowflake_account" {
  description = ""
}

variable "snowflake_region" {
  description = ""
}

variable "snowflake_warehouse" {
  description = ""
}

variable "snowflake_warehouse_size" {
  description = ""
}
