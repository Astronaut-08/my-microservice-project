output "vpc_id" {
  description = "ID"
  value = aws_vpc.main.id
}

output "public_subnets" {
  description = "public subnets ID"
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "private subnets ID"
  value = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "gateway ID"
  value = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "NAT gateway ID"
  value = aws_nat_gateway.main.id
}
