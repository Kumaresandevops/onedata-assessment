variable "project_name"       { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "alb_sg_id"          { type = string }
variable "target_group_arn"   { type = string }
variable "container_image"    { type = string }
variable "container_port"     { type = number; default = 80 }
variable "cpu"                { type = number; default = 256 }
variable "memory"             { type = number; default = 512 }
variable "min_capacity"       { type = number; default = 1 }
variable "max_capacity"       { type = number; default = 4 }
