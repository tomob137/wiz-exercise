# AWS trusts GitHub's token issuer...
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
locals {
  github_sub = "repo:tomob137@346979058/wiz-exercise@1434853831"
}
# ...but only for YOUR repo, and only main, pull requests or the production environment.
resource "aws_iam_role" "github_actions" {
  name = "${var.name}-github-actions"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = [
            "${local.github_sub}:ref:refs/heads/main",
            "${local.github_sub}:pull_request",
            "${local.github_sub}:environment:production"
          ]
        }
      }
    }]
  })
}

# Lab shortcut: admin. In production, split into a read-only plan role
# and a narrower apply role (see the panel questions).
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}