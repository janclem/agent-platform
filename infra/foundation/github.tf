import {
  to = github_repository.agent_platform
  id = "agent-platform"
}

resource "github_repository" "agent_platform" {
  name        = "agent-platform"
  description = "Personal agent automation platform"
  visibility  = "public"

  has_issues   = true
  has_wiki     = false
  has_projects = false

  allow_squash_merge     = true
  allow_merge_commit     = false
  allow_rebase_merge     = false
  delete_branch_on_merge = true

  security_and_analysis {
    secret_scanning { status = "enabled" }
    secret_scanning_push_protection { status = "enabled" }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_vulnerability_alerts" "agent_platform" {
  repository = github_repository.agent_platform.name
  enabled    = true
}

resource "github_repository_dependabot_security_updates" "agent_platform" {
  repository = github_repository.agent_platform.name
  enabled    = true

  depends_on = [github_repository_vulnerability_alerts.agent_platform]
}

resource "github_repository_ruleset" "agent_platform_main" {
  name        = "main"
  repository  = github_repository.agent_platform.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      required_approving_review_count = 0 # solo for now; checks become the gate later
    }
  }
}
