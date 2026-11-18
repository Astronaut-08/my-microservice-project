output "rds_endpoint" {
  description = "Endpoint of RDS instance or Aurora cluster"
  value = try(
    aws_db_instance.standard[0].endpoint,
    aws_rds_cluster.aurora[0].endpoint
  )
}

output "rds_reader_endpoint" {
  description = "Reader endpoint of Aurora cluster"
  value       = try(aws_rds_cluster.aurora[0].reader_endpoint, null)
}

output "rds_port" {
  value = try(
    aws_db_instance.standard[0].port,
    aws_rds_cluster.aurora[0].port
  )
}

output "security_group_id" {
  value = aws_security_group.rds.id
}