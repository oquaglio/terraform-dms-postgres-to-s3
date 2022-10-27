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
  default     = "postgres-dms-stack"
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


variable "source_db_identifier" {
  default     = "oq-rds-postgres-1"
  description = "RDS DB Identiifer"
}

variable "source_db_name" {
  default     = "postgres"
  description = "Name of the database in the RDS"
}

variable "source_db_port" {
  description = "The port the Application Server will access the database on"
  default     = 5432
}

variable "source_username" {
  description = "Username to access the source database"
}

variable "source_password" {
  description = "Password of the source database"
}


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
