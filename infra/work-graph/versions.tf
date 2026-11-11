# Adapted from Robbie-Palmer/hq (infra/work-graph), AGPL-3.0.
terraform {
  required_version = ">= 1.17"

  # HCP stores the state. The workspace uses local execution because the
  # credential helpers need 1Password and Doppler access at apply time.
  cloud {
    organization = "terraform-clemetson"
    workspaces { name = "work-graph" }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.52"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "cloudflare" {
  # CLOUDFLARE_API_TOKEN comes from 1Password through scripts/op-terraform-env.sh.
}
