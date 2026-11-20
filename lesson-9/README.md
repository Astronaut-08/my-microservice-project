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
│   ├── monitoring/
│   │   ├── monitoring.tf
│   │   ├── variables.tf
│   │   └── versions.tf
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

Параметри `max_connections`, `log_statement` і `work_mem` передаються через змінну `parameters`. Для звичайного RDS вони додаються до instance parameter group. Для Aurora PostgreSQL вони мають бути в DB parameter group, призначеній кожному cluster instance. Параметри та їхні значення мають підтримуватися обраною версією engine.

Зміна `use_aurora` змінює тип бази. Перевіряйте `terraform plan` перед `apply`: перехід зі звичайного RDS на Aurora у поточному стані планує видалення звичайної бази та створення Aurora. Не застосовуйте цей план, якщо потрібно зберегти наявну базу. Пароль, указаний у `main.tf`, призначений лише для навчального середовища; не використовуйте його повторно в інших системах.

Виходи модуля: `rds_endpoint`, `rds_reader_endpoint`, `rds_port` і `security_group_id`. Для звичайного RDS reader endpoint буде `null`.

```hcl
module "rds" {
  source = "./modules/rds"

  name       = "myapp-db"
  use_aurora = false

  engine                     = "postgres"
  engine_version             = "15.19"
  parameter_group_family_rds = "postgres15"

  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "myapp"
  username                = "postgres"
  password                = "навчальний-пароль"
  vpc_id                  = module.vpc.vpc_id
  subnet_private_ids      = module.vpc.private_subnets
  subnet_public_ids       = module.vpc.public_subnets
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 1

  db_port             = 5432
  allowed_cidr_blocks = ["10.0.0.0/16"]

  parameters = {
    max_connections = "200"
    log_statement   = "all"
    work_mem        = "4096"
  }

  tags = {
    Environment = "dev"
  }

  skip_final_snapshot = true
  # Якщо встановити false, задайте неповторюваний identifier:
  # skip_final_snapshot       = false
  # final_snapshot_identifier = "myapp-db-final-20261119"
}
```
Для звичайного RDS тип і версія задаються через `engine` та `engine_version`; узгодьте `parameter_group_family_rds` із вибраним engine та версією. Наприклад, для PostgreSQL це `engine = "postgres"` і family на зразок `postgres15`, а для MySQL задайте `engine = "mysql"` та відповідну MySQL family. Для Aurora використовуйте `engine_cluster`, `engine_version_cluster` і `parameter_group_family_aurora`. Доступність версій перевіряйте у вибраному AWS-регіоні. Клас інстансу для звичайного RDS і Aurora задається спільною змінною `instance_class`, наприклад `db.t3.micro`; вибирайте клас, сумісний із engine та регіоном, і перевіряйте його вартість.

| Змінна                          | Тип             | Значення за замовчуванням | Опис |
| ---                             | ---             | ---                       | --- |
| `name`                          | `string`        | обов’язкова               | Назва RDS instance або Aurora cluster. |
| `engine`                        | `string`        | `postgres`                | Engine звичайного RDS, наприклад `postgres` або `mysql`. |
| `engine_cluster`                | `string`        | `aurora-postgresql`       | Engine Aurora, наприклад `aurora-postgresql` або `aurora-mysql`. |
| `aurora_instance_count`         | `number`        | `2`                       | Кількість Aurora instances: writer і, за потреби, reader. |
| `engine_version`                | `string`        | `14.7`                    | Версія engine звичайного RDS instance. |
| `instance_class`                | `string`        | `db.t3.micro`             | Клас RDS instance або кожного Aurora instance. |
| `allocated_storage`             | `number`        | `20`                      | Обсяг диска у GiB для звичайного RDS; Aurora не використовує це значення. |
| `db_name`                       | `string`        | обов’язкова               | Назва початкової бази даних. |
| `username`                      | `string`        | обов’язкова               | Ім’я головного користувача БД. |
| `password`                      | `string`        | обов’язкова               | Пароль головного користувача БД; змінна позначена `sensitive`. |
| `vpc_id`                        | `string`        | обов’язкова               | ID VPC для бази та її security group. |
| `subnet_private_ids`            | `list(string)`  | обов’язкова               | ID приватних підмереж для DB subnet group. |
| `subnet_public_ids`             | `list(string)`  | обов’язкова               | ID публічних підмереж, якщо база налаштована як публічна. |
| `publicly_accessible`           | `bool`          | `false`                   | Чи має DB instance бути доступним із публічної мережі. |
| `multi_az`                      | `bool`          | `false`                   | Чи вмикати Multi-AZ для звичайного RDS. |
| `parameters`                    | `map(string)`   | `{}`                      | Параметри parameter group бази даних. |
| `use_aurora`                    | `bool`          | `false`                   | `true` створює Aurora; `false` — звичайний RDS instance. |
| `backup_retention_period`       | `number`        | `7`                       | Кількість днів зберігання автоматичних резервних копій. |
| `tags`                          | `map(string)`   | `{}`                      | Додаткові теги AWS-ресурсів. |
| `parameter_group_family_aurora` | `string`        | `aurora-postgresql15`     | Сімейство параметрів Aurora, сумісне з версією engine. |
| `engine_version_cluster`        | `string`        | `15.3`                    | Версія engine Aurora cluster. |
| `parameter_group_family_rds`    | `string`        | `postgres15`              | Сімейство параметрів звичайного RDS, сумісне з engine. |
| `db_port`                       | `number`        | `5432`                    | Порт бази даних. |
| `allowed_cidr_blocks`           | `list(string)`  | `["10.0.0.0/16"]`         | CIDR-діапазони, яким дозволено підключатися до БД. |
| `skip_final_snapshot`           | `bool`          | `true`                    | Пропускати фінальний snapshot при видаленні; `true` не залишає snapshot для відновлення. |
| `final_snapshot_identifier`     | `string`        | `null`                    | Назва фінального snapshot, потрібна коли `skip_final_snapshot = false`. |

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

## Prometheus і Grafana

Моніторинг розгортається у кластері EKS через Helm-модуль `modules/monitoring`, який встановлює chart `kube-prometheus-stack` версії `93.5.0` у namespace `monitoring`.

До складу входять Prometheus, Grafana, Alertmanager, Prometheus Operator, kube-state-metrics і node-exporter. Збирання метрик Etcd, Kubernetes Controller Manager та Scheduler вимкнене, оскільки в EKS цими компонентами керує AWS.

Prometheus зберігає метрики протягом 7 днів на EBS volume розміром 10 GiB. Grafana використовує EBS volume 5 GiB. Для обох PVC задано StorageClass `ebs-sc`, створений для EBS CSI.

### Доступ до Grafana

Grafana доступна як внутрішній `ClusterIP`, тому для локального доступу використовується port-forward. У PowerShell виконайте:

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80
```

Не закриваючи це вікно термінала, відкрийте <http://localhost:3001>. Вхід: користувач `admin`, пароль — значення змінної Terraform `grafana_admin_password`.

Якщо локальний порт `3001` уже зайнятий, виберіть інший, наприклад `3002:80`, і відкрийте відповідний localhost URL. Щоб завершити port-forward, натисніть `Ctrl+C`.

Для локального перегляду інтерфейсу Prometheus в окремому терміналі виконайте:

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Потім відкрийте <http://localhost:9090>.

### Пароль Grafana

Пароль задається через root-змінну Terraform `grafana_admin_password`. У PowerShell встановіть її перед командами Terraform:

```powershell
$env:TF_VAR_grafana_admin_password = "ваш-навчальний-пароль"
terraform plan
terraform apply
```

Змінна `sensitive` приховує пароль у звичайному виводі Terraform, але значення зберігається у Terraform state. Захищайте state-файл або S3 backend так само, як пароль.

### Перевірка стану

```powershell
kubectl get pods,pvc -n monitoring
helm status kube-prometheus-stack -n monitoring
```

Pod-и моніторингу мають бути `Running`, а PVC — `Bound`. Якщо `node-exporter` залишається `Pending`, перевірте події Pod-а:

```powershell
kubectl describe pod <назва-pod-а> -n monitoring
```

Повідомлення `Too many pods` означає, що на відповідному вузлі вичерпано ліміт Pod-ів. У такому разі частина метрик вузла може бути відсутня.

Цей модуль збирає метрики EKS/Kubernetes. Метрики RDS до Prometheus автоматично не додаються; для них потрібно окремо налаштувати інтеграцію з CloudWatch.

## Призначення основних модулів

- **S3 backend** — S3 bucket для Terraform state та DynamoDB table.
- **VPC** — VPC, публічні й приватні підмережі, Internet Gateway і NAT Gateway.
- **ECR** — приватний Docker registry.
- **EKS** — Kubernetes cluster, node group і EBS CSI driver.
- **RDS** — перемикний модуль для звичайної RDS instance або Aurora.
- **Jenkins та Argo CD** — Helm-розгортання інструментів у Kubernetes.
- **Monitoring** — Prometheus, Grafana, Alertmanager та метрики Kubernetes у EKS.
