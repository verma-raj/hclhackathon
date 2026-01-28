
output "lb_security_grp_info" {
  value = aws_security_group.SG.id
}

output "alb_dns_name" {
  value = aws_lb.ALB.dns_name
}