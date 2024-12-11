variable "aws_region" {
  description = "AWS region"
  type = string
  default = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type = string
  default = "bgd-dpl"
}

variable "environment" {
  description = "Project environment"
  type = string
  default = "dev"
}

variable "resources_tags" {
  description = "value"
  type = map(string)
  default = {}
}

variable "container_image_url" {
  description = "URL of container image"
  type = string
}

variable "container_port" {
  description = "Port of container"
  type = number
  default = 80
}