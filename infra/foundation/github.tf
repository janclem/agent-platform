# Every repository the platform manages. Add a project here, plan, and apply;
# then fill it from the Copier template by pull request.
locals {
  repositories = {
    agent-platform = {
      description = "Personal agent automation platform"
      auto_init   = false # existed before Terraform managed it
    }
  }
}

module "repository" {
  source   = "./modules/project-repo"
  for_each = local.repositories

  name        = each.key
  description = each.value.description
  auto_init   = try(each.value.auto_init, true)
  visibility  = try(each.value.visibility, "public")
}

moved {
  from = github_repository.agent_platform
  to   = module.repository["agent-platform"].github_repository.this
}

moved {
  from = github_repository_vulnerability_alerts.agent_platform
  to   = module.repository["agent-platform"].github_repository_vulnerability_alerts.this
}

moved {
  from = github_repository_dependabot_security_updates.agent_platform
  to   = module.repository["agent-platform"].github_repository_dependabot_security_updates.this
}

moved {
  from = github_repository_ruleset.agent_platform_main
  to   = module.repository["agent-platform"].github_repository_ruleset.main
}
