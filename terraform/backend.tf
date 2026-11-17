# Partial configuration. Bucket, region and locking come from
# backend.<env>.hcl, written by scripts/bootstrap.sh, so one root module
# serves every account. Workspaces keep each environment's state apart.
terraform {
  backend "s3" {
    key = "showcase/terraform.tfstate"
  }
}
