locals {
  required_tags = {
    project_name = var.project_name,
    environment = var.environment    
  }
  name_prefix = "${var.project_name}-${var.environment}"
  
  network_resource_output = jsondecode(data.aws_ssm_parameter.network_resources.value)
  ecs_resource_output = jsondecode(data.aws_ssm_parameter.ecs_resources.value)

  tags = merge(local.required_tags, var.resources_tags)
}


data "aws_ssm_parameter" "network_resources" {
  name =  "/${local.name_prefix}/network_resource_output"
  with_decryption = true
}

data "aws_ssm_parameter" "ecs_resources" {
  name =  "/${local.name_prefix}/ecs_resource_output"
  with_decryption = true
}

module "codedeploy-for-ecs" {
  source  = "faros-ai/codedeploy-for-ecs/aws"
  version = "1.3.3"
  
  name                       = "${local.name_prefix}-ecs-codedeploy"
  ecs_cluster_name           = local.ecs_resources["cluster_name"]
  ecs_service_name           = local.ecs_resources["service_name"]
  lb_listener_arns           = [local.network_resource_output["aws_lb_blue_tg_arn"],local.network_resource_output["aws_lb_green_tg_arn"]]
  blue_lb_target_group_name  = local.network_resource_output["aws_lb_blue_tg_name"]
  green_lb_target_group_name = local.network_resource_output["aws_lb_green_tg_name"]

  auto_rollback_enabled            = true
  auto_rollback_events             = ["DEPLOYMENT_FAILURE"]
  action_on_timeout                = "STOP_DEPLOYMENT"
  wait_time_in_minutes             = 20
  termination_wait_time_in_minutes = 20
  test_traffic_route_listener_arns = []
  iam_path                         = "/service-role/"
  description                      = "ECS service blue-green deployment with CodeDeploy"

  tags = local.tags
}