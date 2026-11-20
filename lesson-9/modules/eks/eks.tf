# IAM-роль для EKS-кластера
resource "aws_iam_role" "eks" {
  # Ім'я IAM-ролі для кластера EKS
  name = "${var.cluster_name}-eks-cluster"

  # Політика довіри дозволяє сервісу EKS використовувати цю роль.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# Прив'язка IAM-ролі до політики AmazonEKSClusterPolicy
resource "aws_iam_role_policy_attachment" "eks" {
  # ARN політики, що надає дозволи для EKS-кластера
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

  # IAM-роль, до якої прив'язується політика
  role = aws_iam_role.eks.name
}

# IAM-роль і дозволи для EC2-вузлів кластера.
resource "aws_iam_role" "nodes" {
  name = "${var.cluster_name}-eks-nodes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# Створення EKS-кластера
resource "aws_eks_cluster" "eks" {
  # Назва кластера
  name = var.cluster_name

  # ARN IAM-ролі, яка потрібна для керування кластером
  role_arn = aws_iam_role.eks.arn

  # Налаштування мережі (VPC)
  vpc_config {
    endpoint_private_access = true           # Включає приватний доступ до API-сервера
    endpoint_public_access  = true           # Включає публічний доступ до API-сервера
    subnet_ids              = var.subnet_ids # Список підмереж, де буде працювати EKS
  }

  # Налаштування доступу до EKS-кластера
  access_config {
    authentication_mode                         = "API" # Автентифікація через API
    bootstrap_cluster_creator_admin_permissions = true  # Надає адміністративні права користувачу, який створив кластер
  }

  # Залежність від IAM-політики для ролі EKS
  depends_on = [aws_iam_role_policy_attachment.eks]
}

# Керована група EC2-вузлів, які запускають Kubernetes workloads.
resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.instance_type]

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
  ]
}