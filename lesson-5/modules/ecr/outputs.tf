output "ecr_url" {
  description = "URL"
  value = aws_ecr_repository.repo.repository_url
}