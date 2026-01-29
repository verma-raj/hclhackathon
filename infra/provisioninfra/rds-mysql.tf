data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "mysql" {
  name        = "rds-mysql-sg"
  description = "Allow MySQL inbound from allowed CIDR"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.cidrblock]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "rds-mysql-subnets"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_instance" "mysql" {
  identifier             = "free-tier-mysql"
  engine                 = "mysql"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.mysql.id]

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  publicly_accessible   = true
  multi_az              = false
  skip_final_snapshot   = true
  deletion_protection   = false
  backup_retention_period = 0
}

output "mysql_endpoint" {
  value = aws_db_instance.mysql.address
}
