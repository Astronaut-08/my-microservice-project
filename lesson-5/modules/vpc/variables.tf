variable "vpc_cidr_block" {
  description = "CIDR for vpc"
  type = string
}

variable "public_subnets" {
  description = "List CIDR for public subnetwork"
  type = list(string)
}

variable "private_subnets" {
  description = "List CIDR for private subnetwork"
  type = list(string)
}

variable "availability_zones" {
  description = "List of zones"
  type = list(string)
}

variable "vpc_name" {
  description = "vpc name"
  type = string
}