variable "cidrblock" {
  type = string
}

variable "instance_tenancy" {
  type = string
}

variable "ami" {
  type    = string
  default = "ami-0399f618a28796459" // Apache golden image on Ubuntu
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "associate_public_ip_address" {
  type    = bool
  default = true
}

variable "subnet_pub_CIDR_BLOCK" { // Subnet CIDR
  type    = list(any)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "subnet_AZS" {
  type    = list(any)
  default = ["us-east-1a", "us-east-1b"]
}

variable "aws_region" {
  type = string
}








