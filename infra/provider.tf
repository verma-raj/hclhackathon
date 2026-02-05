terraform {
  required_version = ">= 1.9.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70.0"

    }

  }
}

terraform {
  backend "s3" {
    bucket  = "terraform-statefile-20260125"
    region  = "us-east-1"
    key     = "ecs-fargate/terraform.tfstate"
    encrypt = true
  }

}

provider "aws" {
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
  region     = var.AWS_REGION
  default_tags {
    tags = {
        Project     = "hackathon"
        Environment = "dev"
        Owner = "Rajiv"
    }
  }
}
