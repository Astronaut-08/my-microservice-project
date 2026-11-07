# terraform {
#   backend "s3" {
#     bucket         = "volodymyr-train-lesson-5"
#     key            = "lesson-7/terraform.tfstate"
#     region         = "us-west-2"
#     # dynamodb_table = "terraform-locks"
#     encrypt        = true
#     use_lockfile   = true
#   }
# }
