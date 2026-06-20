variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used to tag/name all resources."
  type        = string
  default     = "spot-singleton"
}

variable "instance_type" {
  description = "EC2 instance type. Requirement is t3.micro."
  type        = string
  default     = "t3.micro"
}

variable "spot_max_price" {
  description = "Maximum spot price per hour (USD). Leave null to cap at the current On-Demand price (AWS default behavior)."
  type        = string
  default     = null
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access. Leave null to rely on SSM Session Manager only (instance profile already grants this)."
  type        = string
  default     = null
}

variable "ssh_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the instance on port 22. Leave empty to disable inbound SSH entirely (recommended; use SSM Session Manager instead)."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC to deploy into. Leave null to use the account/region default VPC."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs the Auto Scaling Group may launch the instance into. Leave empty to use all default-VPC subnets."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags applied to all taggable resources."
  type        = map(string)
  default     = {}
}
