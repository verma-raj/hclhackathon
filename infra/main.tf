

module "aws_resources" {
  source           = ".\\provisioninfra"
  cidrblock        = var.vpc_CIDR_BLOCK
  instance_tenancy = var.INSTANCE_TENANCY
  aws_region       = var.AWS_REGION
}
