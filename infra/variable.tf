variable "AWS_ACCESS_KEY" {
  description = "AWS_ACCESS_KEY of the user"
  type        = string
  default     = "AKIA3DE3IPOUUNCGWJO2"
}
variable "AWS_SECRET_KEY" {
  description = "AWS_SECRET_KEY of the user"
  type        = string
  default     = "PWTa+lye/YUilxTwIXyXBrki+eIWauukF/G7KaOx"
}

variable "AWS_REGION" {
  description = "AWS_REGION of the infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "vpc_CIDR_BLOCK" { // VPC CIDR
  type    = string
  default = "10.0.0.0/16"
}
variable "INSTANCE_TENANCY" {
  default = "default"
}

variable "INSTANCE_TYPE" {
  type    = string
  default = "t2.micro"
}


