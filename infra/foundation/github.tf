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
  allow_auto_merge       = true # lets Renovate use GitHub auto-merge once required checks pass

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
      required_approving_review_count = 0 # solo for now; the ci check is the gate
    }

    required_status_checks {
      strict_required_status_checks_policy = false

      required_check {
        context        = "platform / checks" # job `platform` calling checks.yml
        integration_id = 15368               # GitHub Actions
      }
    }
  }
}
