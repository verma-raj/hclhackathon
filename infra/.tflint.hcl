plugin "terraform" {
  enabled = true
  preset  = "recommended"
}



############################################
# Global behavior
############################################
config {
  module              = true        # Inspect called modules in infra/provisioninfra/*
  disabled_by_default = false
  # You can turn on "force = true" in CI to continue listing findings even if errors occur.
}

############################################
# Terraform language rules (pin versions, naming, docs, unused, etc.)
# NOTE: The Terraform ruleset is bundled with TFLint; defining the plugin
# is only required if you want to pin a specific version.
############################################


# Strongly recommended language-level rules
rule "terraform_required_version"     { enabled = true }   # Require Terraform CLI version
rule "terraform_required_providers"   { enabled = true }   # Require provider versions
rule "terraform_unused_declarations"  { enabled = true }   # Catch dead code
rule "terraform_typed_variables"      { enabled = true }   # Variables must have types
rule "terraform_documented_variables" { enabled = true }   # Variables need descriptions
rule "terraform_documented_outputs"   { enabled = true }   # Outputs need descriptions
rule "terraform_naming_convention"    { enabled = true }   # Enforce snake_case, etc.
# Optionally: rule "terraform_module_version" { enabled = true } # Pin module versions

############################################
# AWS provider rules (ECS, ALB, VPC, S3, etc.)
############################################
plugin "aws" {
  enabled = true
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
############################################
# Tagging policy (apply org-required tags everywhere)
############################################
# Require that AWS resources carry a minimum tag set.
rule "aws_resource_missing_tags" {
  enabled = true
  # Tailor to your org's policy (example set):
  tags    = ["Name", "Environment", "Owner", "Application"]
  # Optionally exclude third-party modules by source address, e.g.:
  # exclude = ["terraform-aws-modules/*"]
}

############################################
# ALB / ELBv2 hygiene
############################################
# Subnets/Security groups for ALB should be valid in target VPC
rule "aws_alb_invalid_subnet"          { enabled = true }
rule "aws_alb_invalid_security_group"  { enabled = true }
# Routing sanity (targets, protocols)
rule "aws_security_group_invalid_protocol" { enabled = true }
rule "aws_security_group_rule_invalid_protocol" { enabled = true }
rule "aws_security_group_rule_deprecated"       { enabled = true }

############################################
# ECS + Fargate checks
############################################
# Catch invalid launch types, network modes, runtime/deprecated settings, etc.
# Many of these are auto-generated from the AWS provider schema.
rule "aws_ecs_task_set_invalid_launch_type" { enabled = true }   # FARGATE/EC2/EXTERNAL
# If you use EC2 anywhere else, also enable instance type sanity:
rule "aws_instance_previous_type"           { enabled = true }   # Avoid previous-gen types

############################################
# VPC/Subnet/Route sanity
############################################
rule "aws_route_not_specified_target"     { enabled = true }
rule "aws_route_specified_multiple_targets" { enabled = true }

############################################
# S3 backend hygiene (naming; consider versioning/encryption policy in code review)
############################################
# Basic S3 bucket naming validation:
rule "aws_s3_bucket_name" {
  enabled = true
  # Optionally enforce a prefix or regex:
  prefix = "tfstate-"     # if you prefix state buckets uniformly
  regex  = "^[a-z0-9.-]{3,63}$"
}

############################################
# Helpful best-practice rails
############################################
rule "aws_lambda_function_deprecated_runtime" { enabled = true } # if you have any Lambda glue
rule "aws_provider_missing_default_tags"      { enabled = true } # encourage default_tags block
# You can add additional service-specific rules you use frequently.

############################################
# Optional: Deep checking (API-backed validation)
# Enable only in a privileged CI stage with AWS creds and controlled latency.
############################################
# config {
#   deep_checking = true   # (If supported by your TFLint version; see plugin docs)
# }
# ...or enable deep-only rules individually as needed.
