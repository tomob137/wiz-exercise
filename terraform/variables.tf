variable "region" {
  description = "AWS region from the CloudLabs sandbox"
  type        = string
}

variable "name" {
  description = "Prefix for resource names"
  type        = string
  default     = "wiz"
}

variable "ssh_public_key" {
  description = "Contents of ~/.ssh/wiz-exercise.pub"
  type        = string
}

variable "mongo_admin_password" {
  description = "MongoDB admin password (letters and numbers only)"
  type        = string
  sensitive   = true
}

variable "mongo_app_password" {
  description = "Password for the app's own MongoDB user (letters and numbers only)"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "owner/repo allowed to deploy through OIDC, e.g. tobrien/wiz-exercise"
  type        = string
}