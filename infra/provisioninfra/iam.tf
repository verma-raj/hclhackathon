resource "aws_iam_role_policy" "ecs_iam_policy" {
  name = "MYECSTaskExecutionRolePolicy"
  role = aws_iam_role.ecs_iam_role.id
  policy = file("${path.module}/MyECSTaskExecutionRolePolicy.json")
}

resource "aws_iam_role" "ecs_iam_role" {
  name = "MYECSTaskExecutionRole"
  assume_role_policy = file("${path.module}/MyECSTaskExecutionRole.json")
}