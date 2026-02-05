plugin "terraform" {
  enabled = true
  preset  = "recommended"
}



############################################
# Global behavior
############################################

plugin "aws" {
  enabled = true
  # Pin a recent version (example; you can bump to latest you use)
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}


############################################
# Tagging policy (apply org-required tags everywhere)
############################################
# Require that AWS resources carry a minimum tag set.
#rule "aws_resource_missing_tags" {
#  enabled = true
#  tags    = ["Name", "Environment", "Project"]
  # Optionally exclude third-par 
#}

############################################
# Helpful best-practice rails  ---- For testing purpose
############################################
# encourage default_tags block
rule "aws_provider_missing_default_tags" { 
  enabled = true 
  tags    = ["Project", "Environment", "Owner"]
} 


