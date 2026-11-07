terraform {
  required_version = ">= 1.17"

  cloud {
    organization = "terraform-clemetson"
    workspaces { name = "foundation" }
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}

provider "github" {
  owner = "janclem" # token comes from GITHUB_TOKEN in the HCP workspace
}
