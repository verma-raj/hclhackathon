/**************************/
/*  LOAD BALANCER CREATION*/
/***************************/
resource "aws_lb" "ALB" {    // Create Application load balancer
  name               = "ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.SG.id]
  subnets            = [for subnet in aws_subnet.pub_subnet : subnet.id]

  enable_deletion_protection = false

  tags = {
    Name = "hackathon"
  }
}

resource "aws_lb_target_group" "lb_tg" { // Creation of target group
  health_check {
    interval            = 5
    healthy_threshold   = 3
    path                = "/"
    protocol            = "HTTP"
    timeout             = 3
    unhealthy_threshold = 3
  }
  name     = "lb-tg"
  port     = 8080
  protocol = "HTTP"
  target_type = "ip"
  vpc_id   = aws_vpc.vpc.id

  tags = {
    Name = "Hackathon"
  }
}

resource "aws_lb_listener" "lb_listener" { // creation of listener
  load_balancer_arn = aws_lb.ALB.arn
  port              = "8080"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
}