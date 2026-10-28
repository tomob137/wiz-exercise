resource "aws_ecr_repository" "tasky" {
  name                 = "tasky"
  image_tag_mutability = "IMMUTABLE" # a tag can never be overwritten
  force_delete         = true        # lets terraform destroy remove it with images inside

  image_scanning_configuration {
    scan_on_push = true # AWS scans each pushed image for known CVEs
  }
}

output "ecr_url" {
  value = aws_ecr_repository.tasky.repository_url
}