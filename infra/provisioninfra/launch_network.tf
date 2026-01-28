/*******
/ VPC Creation
*******/
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidrblock
  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = true
  tags = {
    Name = "vpc"
  }
}
output "returnvpcid" {
  value = aws_vpc.vpc.id
}

/*********************
Public Subnet Creation
**********************/
resource "aws_subnet" "pub_subnet" { // Public Subnet
  vpc_id     = aws_vpc.vpc.id
  count      = length(var.subnet_pub_CIDR_BLOCK)
  cidr_block = element(var.subnet_pub_CIDR_BLOCK, count.index)
  //count  = length(var.subnet_AZS)
  availability_zone       = element(var.subnet_AZS, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "pubsubnet-${count.index + 1}"
  }
}

data "aws_subnet" "pubsubnetinfo" {
  count = length(var.subnet_pub_CIDR_BLOCK)
  filter {
    name   = "tag:Name"
    values = ["pubsubnet-${count.index + 1}"]
  }
  depends_on = [aws_subnet.pub_subnet]
}

output "returnpubsubnetid" {
  value = data.aws_subnet.pubsubnetinfo.*.id
}

/**************************
/ INTERNET GATEWAY CREATION
***************************/
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "IGW"
  }
}
/**********************************
/  Elastic IP
/**********************************/
resource "aws_eip" "eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}
/***********************************
/ ROUTE TABLE CREATION & Association
************************************/
resource "aws_route_table" "pubRT" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "pubRT"
  }
  depends_on = [
    aws_subnet.pub_subnet
  ]

}

resource "aws_route_table_association" "pub_route_association" {
  //count = length(var.subnet_CIDR_BLOCK )
  for_each       = { for idx, subnet in data.aws_subnet.pubsubnetinfo[*] : idx => subnet }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.pubRT.id
  depends_on = [
    aws_route_table.pubRT
  ]

}

/**************************
/ Key-pair creation
/*************************/
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "TF_key" {
  key_name   = "TF_key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "local_file" "TF_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tfkey"
}
/******************************************/
/* SECURITY GROUP                         */
/******************************************/
locals {
  lb_ingress_rules = [{
    port        = 8080
    protocol    = "tcp"
    description = "For ALB HTTP"
    cidr_blocks = ["0.0.0.0/0"]
    }]

}

resource "aws_security_group" "SG" {
  name        = "lb-SG"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = local.lb_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "hackathon"
  }
}



