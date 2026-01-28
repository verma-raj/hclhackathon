// Create ECS Cluster with Fargate

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"
  region = var.aws_region

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    Name = "hackathon"
  }

}

resource "aws_ecs_service" "ecs_svc" {
  name                               = "ecs-clst-svc"
  cluster                            = aws_ecs_cluster.ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.ecs_taskdef.arn
  launch_type                        = "FARGATE"
  desired_count                      = 2
  platform_version                   = "LATEST"
  //iam_role                           = aws_iam_role.ecs_iam_role.arn
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  depends_on      = [aws_lb_listener.lb_listener, aws_iam_role_policy.ecs_iam_policy]
  deployment_configuration {
    strategy = "ROLLING"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lb_tg.arn
    container_name   = "hackathon"
    container_port   = 8080
  }

  network_configuration {
     assign_public_ip   = true
     security_groups    = [aws_security_group.SG.id]
     subnets      = [for subnet in aws_subnet.pub_subnet : subnet.id]
  }


}

resource "aws_ecs_task_definition" "ecs_taskdef" {
  family                   = "hackathon_ecs_taskdef"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_iam_role.arn
  container_definitions    = jsonencode([
  {
    "name": "hackathon",
    "image": "762682309545.dkr.ecr.us-east-1.amazonaws.com/hackathon:v1.0",
    "cpu": 1024,
    "memory": 2048,
    "essential": true
    portMappings = [
     {
       containerPort  = 8080
       hostPort       = 8080
     }
    ]
  }
])
}

data "aws_ecs_task_definition" "ecs_taskdef" {
  task_definition = aws_ecs_task_definition.ecs_taskdef.family
}



