locals {
  required_tags = {
    project_name = var.project_name,
    environment = var.environment    
  }
  name_prefix = "${var.project_name}-${var.environment}"

  port = var.container_port
  image_url = var.container_image_url
  
  tags = merge(local.required_tags, var.resources_tags)
}

resource "aws_ecs_task_definition" "task_def" {
  family = "${local.name_prefix}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  container_definitions = jsonencode([
    {
      cpu       = 1024
      memory    = 2048
      essential = true
      image     = local.image_url
      port_mappings = [
        {
          name          = "${local.name_prefix}"
          containerPort = local.port
          hostPort      = local.port
          protocol      = "tcp"
        }
      ]

      enable_cloudwatch_logging = false
      # log_configuration = {
      #   logDriver = "awsfirelens"
      #   options = {
      #     Name                    = "firehose"
      #     region                  = "eu-west-1"
      #     delivery_stream         = "my-stream"
      #     log-driver-buffer-limit = "2097152"
      #   }
      # }
      # memory_reservation = 100
      
      runtime_platform = {
        operating_system_family = "LINUX"
        cpu_architecture        = "X86_64"
      }
    }
  ])
}