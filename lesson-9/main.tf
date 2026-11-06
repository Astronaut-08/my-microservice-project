# Підключаємо модуль S3 та DynamoDB
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "volodymyr-train-lesson-5"
  table_name  = "terraform-locks"
}

# Підключаємо модуль VPC
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "lesson-5-vpc"
}

# Підключаємо модуль ECR
module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "lesson-5-ecr"
  scan_on_push = true
}

# Підключаємо модуль EKS
module "eks" {
  source        = "./modules/eks"
  cluster_name  = "eks-cluster-demo"         # Назва кластера
  subnet_ids    = module.vpc.private_subnets # Приватні підмережі для EKS і вузлів
  instance_type = "t3.medium"                # Тип інстансів
  desired_size  = 1                          # Бажана кількість нодів
  max_size      = 2                          # Максимальна кількість нодів
  min_size      = 1                          # Мінімальна кількість нодів
}
