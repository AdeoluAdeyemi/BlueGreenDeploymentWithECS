variable "project_name" {
  description = "Name of the project"
  type = string
  default = "bgd-dpl"
}

variable "environment" {
  description = "Name of the environment"
  type = string
  default = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type = string
  default = "us-east-1"
}

variable "resources_tags" {
  description = "Tags to set for all resources"
  type = map(string)
  default = {}
}
