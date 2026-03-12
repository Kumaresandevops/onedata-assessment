variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "aurora-secrets-demo"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_master_username" {
  description = "Master username for Aurora cluster"
  type        = string
  default     = "dbadmin"
}

variable "rotation_days" {
  description = "Number of days between secret rotations"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "aurora-secrets-demo"
    ManagedBy   = "terraform"
    Environment = "demo"
  }
}
