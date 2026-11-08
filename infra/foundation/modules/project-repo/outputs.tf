output "name" {
  value = github_repository.this.name
}

output "html_url" {
  value = github_repository.this.html_url
}

output "ruleset_id" {
  value = github_repository_ruleset.main.ruleset_id
}
