locals {
  required_tags = {
    project_name = var.project_name,
    environment = var.environment    
  }
  name_prefix = "${var.project_name}-${var.environment}"

  port = var.container_port
  
  network_resource_output = jsondecode(data.aws_ssm_parameter.network_resources.value)

  tags = merge(local.required_tags, var.resources_tags)
}


data "aws_ssm_parameter" "network_resources" {
  name =  "/${local.name_prefix}/network_resource_output"
  with_decryption = true
}

# locals {
#   network_resource_output = jsondecode(data.aws_ssm_parameter.network_resources.value)
# }

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}



# # IAM Role for ECR Registry
# resource "aws_iam_role" "ecr_terraform" {
#   name = "ecr-tf-role-${local.name_prefix}"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_policy_attachment" "ecs_task_execution_policy" {
#   name       = "ecs-task-execution-policy-attachment"
#   roles      = [aws_iam_role.ecr_terraform.name]
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }


data "aws_ecs_task_definition" "task_def" {
  task_definition = local.name_prefix
}


module "ecs" {
  source = "terraform-aws-modules/ecs/aws"
  version = "5.11.4"

  cluster_name = "${local.name_prefix}-ecs"

  # Create ECS task definition IAM including AmazonECSTaskExecutionRolePolicy
  create_task_exec_policy = true

  # Name to use on IAM role created
  task_exec_iam_role_name = "${local.name_prefix}-ecs-task-role"

  # Use Fargate as capacity provider
  default_capacity_provider_use_fargate = true

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-fargate"
      }
    }
  }

  services = {
    "${local.name_prefix}-service" = {
      cpu    = 1024
      memory = 2048
      
      create_task_definition = false
      task_definition_arn  = data.aws_ecs_task_definition.task_def.arn

      # Container definition(s)
      # container_definitions = {
      #   "${local.name_prefix}" = {
      #     cpu       = 1024
      #     memory    = 2048
      #     essential = true
      #     image     = local.image_url
      #     port_mappings = [
      #       {
      #         name          = "${local.name_prefix}"
      #         containerPort = local.port
      #         hostPort      = local.port
      #         #protocol      = "tcp"
      #       }
      #     ]

      #     enable_cloudwatch_logging = false
      #     # log_configuration = {
      #     #   logDriver = "awsfirelens"
      #     #   options = {
      #     #     Name                    = "firehose"
      #     #     region                  = "eu-west-1"
      #     #     delivery_stream         = "my-stream"
      #     #     log-driver-buffer-limit = "2097152"
      #     #   }
      #     # }
      #     # memory_reservation = 100
      #   }
      # }

      # service_connect_configuration = {
      #   namespace = "${local.name_prefix}"
      #   service = {
      #     client_alias = {
      #       port     = local.port
      #       dns_name = "${local.name_prefix}"
      #     }
      #     port_name      = "${local.name_prefix}"
      #     discovery_name = "${local.name_prefix}"
      #   }
      # }

      load_balancer = {
        service = {
          target_group_arn = local.network_resource_output["aws_lb_blue_tg_arn"]
          container_name   = "${local.name_prefix}"
          container_port   = local.port
        }
      }

      subnet_ids           = local.network_resource_output["subnet_id"]
      security_group_ids   = [local.network_resource_output["security_group_ids"]] 
      assign_public_ip = true      

      deployment_controller = {
        type  = "CODE_DEPLOY"
      }
    }
  }

  tags = local.tags
}

resource "aws_ssm_parameter" "ecs_resource_output" {
  name        = "/${local.name_prefix}/ecs_resource_output"
  description = "The parameter store for ecs resource output"
  type        = "SecureString"
  value       = jsonencode({
    "cluster_name" : module.ecs.cluster_name,
    "service_name" : keys(module.ecs.services)[0]   //lookup(module.ecs.services["service_a"], "url", "test_service_name")
  })
}