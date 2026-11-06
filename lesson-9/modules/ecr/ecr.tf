# create repository
resource "aws_ecr_repository" "repo" {
  name = var.ecr_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
}

# erc policy
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "repo_policy_data" {
  statement {
    sid = "AllowPushPull"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [ "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" ]
    }

    actions = [ 
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
      "ecr:DeleteRepository",
      "ecr:BatchDeleteImage",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
     ]
  }
}


resource "aws_ecr_repository_policy" "repo_policy" {
  repository = aws_ecr_repository.repo.name
  policy = data.aws_iam_policy_document.repo_policy_data.json
}