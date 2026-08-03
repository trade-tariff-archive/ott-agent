# ott-agent/terraform/ecr.tf
resource "aws_ecr_repository" "ott_agent" {
  name                 = "ott-agent"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.ott_agent.repository_url
}
