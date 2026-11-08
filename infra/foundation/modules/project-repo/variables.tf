variable "name" {
  description = "Repository name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "Use lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "description" {
  description = "One-line repository description."
  type        = string
  default     = ""
}

variable "visibility" {
  description = "public or private."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be public or private."
  }
}

variable "auto_init" {
  description = "Create main with an initial commit, so the first real change can arrive by pull request."
  type        = bool
  default     = true
}

variable "required_checks" {
  description = "Status checks (GitHub Actions job names) that must pass before merging to main."
  type        = list(string)
  default     = ["platform / checks"] # job `platform` calling checks.yml
}
