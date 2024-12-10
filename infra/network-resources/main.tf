
# Local variables
locals {
  required_tags = {
    project_name = var.project_name,
    environment = var.environment,
  }

  port = var.container_port
  tags = merge(var.resource_tag, local.required_tags)

  name_prefix = "${var.project_name}-${var.environment}"
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Declare the azs data source
data "aws_availability_zones" "available" {
  state = "available"
}

# Create a VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "vpc-${local.name_prefix}"
  cidr = var.vpc_cidr_block
  
  azs = data.aws_availability_zones.available.names
  private_subnets = slice(var.private_subnet_cidr_blocks, 0, var.private_subnet_count)
  public_subnets  = slice(var.public_subnet_cidr_blocks, 0, var.public_subnet_count)

  # Create an Internet Gateway for public subnets and the related routes that connect them
  create_igw = true

  # Set name for default route table
  default_route_table_name = "rt-${local.name_prefix}"

  tags = local.tags
}

# Create Security Group for HTTP
module "alb_security_group" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "5.2.0"

  name        = "web-sg-${local.name_prefix}"
  description = "Security group for web-server with HTTP ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [var.vpc_cidr_block]
  egress_cidr_blocks = ["0.0.0.0/0"]
  tags = local.tags
}


# Create random 3 chars string
resource "random_string" "lb_id" {
  length  = 3
  special = false
}


# Create Elastic Load Balancer
# module "alb" {
#   source = "terraform-aws-modules/alb/aws"
#   version = "9.12.0"

#   # Ensure load balancer name is unique
#   name = "alb-${random_string.lb_id.result}-${local.name_prefix}"
#   vpc_id  = module.vpc.vpc_id
  
#   # Disable deletion protection
#   enable_deletion_protection = false

#   subnets         = module.vpc.public_subnets
#   security_groups = [module.alb_security_group.security_group_id]

#   # access_logs = {
#   #   bucket = "${local.name_prefix}-alb-logs"
#   # }

#   # listeners = {
#   #   http-forward = {
#   #     port     = 80
#   #     protocol = "HTTP"
#   #     forward = {
#   #       target_group_key = "tg-blue"
#   #     }
#   #   }
#   # }

#   # target_groups = {
#   #   tg-blue = {
#   #     name_prefix      = "blue"
#   #     protocol         = "HTTP"
#   #     port             = 80
#   #     target_type      = "alb"


#   #     health_check = {
#   #       target              = "HTTP:80/"
#   #       interval            = 30
#   #       healthy_threshold   = 2
#   #       unhealthy_threshold = 2
#   #       timeout             = 5
#   #     }
#   #   }

#   #   tg-green = {
#   #     name_prefix      = "green"
#   #     protocol         = "HTTP"
#   #     port             = 80
#   #     target_type      = "alb"

#   #     health_check = {
#   #       target              = "HTTP:80/"
#   #       interval            = 30
#   #       healthy_threshold   = 2
#   #       unhealthy_threshold = 2
#   #       timeout             = 5
#   #     }
#   #   }
# //}
#   tags = local.tags
# }


resource "aws_lb" "app_lb" {  
  # Ensure load balancer name is unique
  name = "alb-${random_string.lb_id.result}-${local.name_prefix}"
  
  # Disable deletion protection
  enable_deletion_protection = false

  load_balancer_type = "application"

  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_security_group.security_group_id]
  
  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.id
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags = local.tags
}

resource "aws_lb_target_group" "tg_blue" {
  name     = "${local.name_prefix}-alb-tg-blue"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "ip"

  tags = local.tags

  health_check  {
    matcher             = 200
    port                = 80
    path                = "/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

resource "aws_lb_target_group" "tg_green" {
  name     = "${local.name_prefix}-alb-tg-green"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "ip"
  
  tags = local.tags

  
  health_check {
    matcher             = 200
    port                = 80
    path                = "/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = local.port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_blue.arn
  }

  tags = local.tags
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "2.3.0"
  
  repository_name = "ecr-${local.name_prefix}"

  #repository_read_write_access_arns = [aws_iam_role.ecr_terraform.arn]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = local.tags
}


resource "aws_ssm_parameter" "network_resource_output" {
  name        = "/${local.name_prefix}/network_resource_output"
  description = "The parameter store for network resource output"
  type        = "SecureString"
  value       = jsonencode({
    "subnet_id" : module.vpc.public_subnets,
    "security_group_ids" : module.alb_security_group.security_group_id,
    "aws_lb_blue_tg_arn" : aws_lb_target_group.tg_blue.arn,
    "aws_lb_blue_tg_name" : aws_lb_target_group.tg_blue.name,
    "aws_lb_green_tg_name" : aws_lb_target_group.tg_green.name,
    "aws_lb_green_tg_arn" : aws_lb_target_group.tg_green.arn,
    "aws_lb" : aws_lb.app_lb.id,
    "aws_vpc_id" : module.vpc.vpc_id,
    "aws_lb_listener" : aws_lb_listener.app_listener.id,
  })
  

  tags = local.tags
}