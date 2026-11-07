output "s3_bucket_name" {
  description = "Name of S3-bucket for states"
  value = module.s3_backend.s3_bucket_name
}

output "dynamodb_table_name" {
  description = "Name of DynamoDB for blocking states"
  value = module.s3_backend.dynamodb_table_name
}

output "ecr_url" {
  description = "URL"
  value = module.ecr.ecr_url
}

output "vpc_id" {
  description = "ID"
  value = module.vpc.vpc_id
}

output "public_subnets" {
  description = "public subnets ID"
  value = module.vpc.public_subnets
}

output "private_subnets" {
  description = "private subnets ID"
  value = module.vpc.private_subnets
}

output "internet_gateway_id" {
  description = "gateway ID"
  value = module.vpc.internet_gateway_id
}

output "nat_gateway_id" {
  description = "NAT gateway ID"
  value = module.vpc.nat_gateway_id
}
