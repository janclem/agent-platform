# GitHub deployment environments. Each holds the secrets one CD workflow needs and
# accepts deployments only from main. Secret values are set with `gh secret set
# --env`, never through Terraform, so they stay out of state.

# Work Graph CD (.github/workflows/work-graph-cd.yml). Holds DOPPLER_TOKEN, a
# read-only service token for Doppler work-graph/prd_work_graph (ADR 23).
resource "github_repository_environment" "work_graph_production" {
  repository  = module.repository["agent-platform"].name
  environment = "production-work-graph"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "work_graph_production_main" {
  repository     = github_repository_environment.work_graph_production.repository
  environment    = github_repository_environment.work_graph_production.environment
  branch_pattern = "main"
}
