resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.app_name}"
  image_tag_mutability = "MUTABLE"
}

output "repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}