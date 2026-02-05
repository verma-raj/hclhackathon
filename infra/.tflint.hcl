plugin "terraform" {
  enabled = true
}
# Allow warnings but fail only on errors.
config {
  module              = false
  disabled_by_default = true
  force               = true
}

plugin "aws" {
  enabled = true
  # Pin a recent version (example; you can bump to latest you use)
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

############################################
# Helpful best-practice rails  ---- For testing purpose
############################################
# encourage default_tags block
rule "aws_provider_missing_default_tags" { 
  enabled = true 
  tags    = ["Project", "Environment", "Owner"]
} 


