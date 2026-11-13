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

# Work Graph backup (.github/workflows/work-graph-backup.yml). Holds DOPPLER_TOKEN,
# a read-only service token for Doppler work-graph/prd_work_graph_backup (ADR 21).
# No required reviewers: an approval gate would block the nightly schedule.
resource "github_repository_environment" "work_graph_backup" {
  repository  = module.repository["agent-platform"].name
  environment = "production-work-graph-backup"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "work_graph_backup_main" {
  repository     = github_repository_environment.work_graph_backup.repository
  environment    = github_repository_environment.work_graph_backup.environment
  branch_pattern = "main"
}

# Records that main passed its checks (.github/workflows/ci.yml): the delivery
# signal for platform changes, per the delivery contract's "merged main run of
# platform / checks passed". Holds no secrets.
resource "github_repository_environment" "agent_platform_production" {
  repository  = module.repository["agent-platform"].name
  environment = "production-agent-platform"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "agent_platform_production_main" {
  repository     = github_repository_environment.agent_platform_production.repository
  environment    = github_repository_environment.agent_platform_production.environment
  branch_pattern = "main"
}

# Records a successful `mise run work-graph-infra:apply` from main: the delivery
# signal for infra/work-graph changes. Deployments are created through the API
# by the apply task, not by a workflow. Holds no secrets.
resource "github_repository_environment" "work_graph_infra_production" {
  repository  = module.repository["agent-platform"].name
  environment = "production-work-graph-infra"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "work_graph_infra_production_main" {
  repository     = github_repository_environment.work_graph_infra_production.repository
  environment    = github_repository_environment.work_graph_infra_production.environment
  branch_pattern = "main"
}
