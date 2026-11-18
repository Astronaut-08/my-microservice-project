# Lesson 10 — інфраструктура мікросервісу

Terraform-проєкт створює AWS VPC, EKS, ECR та RDS. Jenkins і Argo CD встановлюються в EKS через Helm.

## Структура проєкту

```text
lesson-9/
├── main.tf
├── backend.tf
├── outputs.tf
├── modules/
│   ├── s3-backend/
│   │   ├── s3.tf
│   │   ├── dynamodb.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vpc/
│   │   ├── vpc.tf
│   │   ├── routes.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecr/
│   │   ├── ecr.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/
│   │   ├── eks.tf
│   │   ├── aws_ebs_csi_driver.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── rds/
│   │   ├── rds.tf
│   │   ├── aurora.tf
│   │   ├── shared.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── jenkins/
│   │   ├── jenkins.tf
│   │   ├── variables.tf
│   │   ├── providers.tf
│   │   ├── values.yaml
│   │   └── outputs.tf
│   └── argo_cd/
│       ├── argo_cd.tf
│       ├── variables.tf
│       ├── values.yaml
│       ├── outputs.tf
│       └── charts/
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
│               └── application.yaml
└── charts/
    └── django-app/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── configmap.yaml
            └── hpa.yaml
```

## Перед початком

Потрібні Terraform, AWS CLI, kubectl, Helm і Docker. Налаштуйте доступ до AWS та перевірте його:

```powershell
aws sts get-caller-identity
```

AWS-користувач має мати дозволи на створення ресурсів, які використовуються проєктом. EKS, NAT Gateway, RDS та Aurora можуть створювати витрати.

## Перше розгортання

На першому запуску EKS-кластер ще не існує, але Kubernetes і Helm providers у `main.tf` звертаються до нього. Тому спочатку створіть VPC та EKS.

1. Тимчасово закоментуйте в `main.tf` блоки `data "aws_eks_cluster"`, `data "aws_eks_cluster_auth"`, providers `kubernetes` і `helm`, а також модулі `jenkins` та `argo_cd`.
2. Тимчасово закоментуйте в кореневому `outputs.tf` виходи `jenkins_release` і `jenkins_namespace`.
3. Перейдіть у каталог `lesson-9` і виконайте:

```powershell
terraform init
terraform plan '-target=module.vpc' '-target=module.eks'
terraform apply '-target=module.vpc' '-target=module.eks'
```

4. Після створення EKS розкоментуйте вимкнені блоки та виконайте повний запуск:

```powershell
terraform plan
terraform apply
```

Під час наступних змін, коли EKS уже створений, достатньо звичайного `terraform plan` і `terraform apply`.

## Віддалений backend для Terraform state

`backend.tf` містить закоментовану конфігурацію S3 backend. Спочатку створіть ресурси S3 і DynamoDB модулем `s3-backend`, залишивши backend закоментованим. Після того як bucket створений:

1. Розкоментуйте блок `terraform { backend "s3" { ... } }` у `backend.tf`.
2. Перевірте, що `bucket`, `key` і `region` відповідають конфігурації.
3. Перенесіть локальний state:

```powershell
terraform init -migrate-state
```

Зараз у `backend.tf` увімкнено S3 lockfile через `use_lockfile = true`. Рядок `dynamodb_table` закоментований, тому таблиця DynamoDB створюється модулем, але backend зараз не використовує її для блокування state.

## RDS-модуль

Модуль `modules/rds` перемикається змінною `use_aurora`:

- `use_aurora = false` створює одну звичайну `aws_db_instance`.
- `use_aurora = true` створює Aurora cluster, його parameter group та кількість cluster instances, задану `aurora_instance_count` (за замовчуванням — дві).

В обох режимах створюються спільні DB subnet group і security group. Якщо `publicly_accessible = false`, база використовує приватні підмережі. Вхідний трафік security group обмежується `allowed_cidr_blocks` і `db_port`.

Engine version та parameter group family мають відповідати одна одній і бути доступними в обраному AWS-регіоні. Доступні версії PostgreSQL можна перевірити так:

```powershell
aws rds describe-db-engine-versions --engine postgres --region us-west-2 --query "DBEngineVersions[].{Version:EngineVersion,Family:DBParameterGroupFamily}" --output table
```

У поточній конфігурації `main.tf` використовується звичайний PostgreSQL: `use_aurora = false`, версія `15.19`, family `postgres15`. Для Aurora потрібно встановити `use_aurora = true` і задати доступні `engine_version_cluster` та `parameter_group_family_aurora`.

Параметри БД передаються через map `parameters`. Наприклад, для PostgreSQL:

```hcl
parameters = {
  max_connections = "200"
  log_statement   = "all"
  work_mem        = "4096"
}
```

Параметри мають підтримуватися обраним engine і parameter group family. Поточний `main.tf` передає `max_connections` та `log_min_duration_statement`.

Зміна `use_aurora` змінює тип бази. Перевіряйте `terraform plan` перед `apply`: перехід зі звичайного RDS на Aurora у поточному стані планує видалення звичайної бази та створення Aurora. Не застосовуйте цей план, якщо потрібно зберегти наявну базу. Пароль, указаний у `main.tf`, призначений лише для навчального середовища; не використовуйте його повторно в інших системах.

Виходи модуля: `rds_endpoint`, `rds_reader_endpoint`, `rds_port` і `security_group_id`. Для звичайного RDS reader endpoint буде `null`.

## Підключення до EKS

```powershell
$clusterName = terraform output -raw eks_cluster_name
aws eks update-kubeconfig --region us-west-2 --name $clusterName

kubectl get nodes
kubectl get pods --all-namespaces
helm list --all-namespaces
```

## Збірка та завантаження Docker-образу в ECR

Terraform створює ECR-репозиторій `lesson-5-ecr`. Перейдіть до каталогу, де розташований Dockerfile, і виконайте в PowerShell:

```powershell
$accountId = aws sts get-caller-identity --query Account --output text
$region = "us-west-2"
$registry = "$accountId.dkr.ecr.$region.amazonaws.com"
$repository = "$registry/lesson-5-ecr"

aws ecr get-login-password --region $region |
  docker login --username AWS --password-stdin $registry

docker build -t lesson-5-ecr .
docker tag lesson-5-ecr:latest "${repository}:latest"
docker push "${repository}:latest"
```

Якщо AWS account або ECR repository відрізняються, оновіть `image.repository` у `charts/django-app/values.yaml`.

## Розгортання Django Helm chart

Перед розгортанням перевірте `charts/django-app/values.yaml`: вкажіть правильний Docker image і параметри підключення до БД. Поточні значення середовища є прикладом і можуть не відповідати створеній RDS-базі.

```powershell
Set-Location D:\neoversity\DevOps\my-microservice-project\lesson-9\charts\django-app
helm upgrade --install django-app . --namespace default
```

## Призначення основних модулів

- **S3 backend** — S3 bucket для Terraform state та DynamoDB table.
- **VPC** — VPC, публічні й приватні підмережі, Internet Gateway і NAT Gateway.
- **ECR** — приватний Docker registry.
- **EKS** — Kubernetes cluster, node group і EBS CSI driver.
- **RDS** — перемикний модуль для звичайної RDS instance або Aurora.
- **Jenkins та Argo CD** — Helm-розгортання інструментів у Kubernetes.
