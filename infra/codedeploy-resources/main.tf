module "codedeploy-for-ecs" {
  source  = "faros-ai/codedeploy-for-ecs/aws"
  version = "1.3.3"
  
  name                       = "example"
  ecs_cluster_name           = "${var.ecs_cluster_name}"
  ecs_service_name           = "${var.ecs_service_name}"
  lb_listener_arns           = ["${var.lb_listener_arns}"]
  blue_lb_target_group_name  = "${var.blue_lb_target_group_name}"
  green_lb_target_group_name = "${var.green_lb_target_group_name}"

  auto_rollback_enabled            = true
  auto_rollback_events             = ["DEPLOYMENT_FAILURE"]
  action_on_timeout                = "STOP_DEPLOYMENT"
  wait_time_in_minutes             = 20
  termination_wait_time_in_minutes = 20
  test_traffic_route_listener_arns = []
  iam_path                         = "/service-role/"
  description                      = "This is example"

  tags = {
    Environment = "prod"
  }
}