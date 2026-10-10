variable "ecr_name" {
  description = "Name of repository"
  type = string
}

variable "scan_on_push" {
  description = "Scan on push"
  type = bool
}