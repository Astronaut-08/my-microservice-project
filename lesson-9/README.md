# Django CI/CD на AWS: Terraform, Jenkins, ECR та Argo CD

1. Terraform створює мережу VPC, EKS-кластер, ECR-репозиторій, Jenkins та Argo CD.
2. Jenkins збирає Docker-образ Django та публікує його в Amazon ECR.
3. Jenkins оновлює тег образу в Helm chart і відправляє зміну до GitHub.
4. Argo CD відстежує Git-репозиторій і розгортає актуальну версію застосунку в EKS.

## Структура проєкту

```text
my-microservice-project/
├── Jenkinsfile
├── docker/
│   └── django/
│       ├── Dockerfile
│       ├── requirements.txt
│       └── config/
│           └── settings.py
└── lesson-9/
    ├── backend.tf
    ├── main.tf
    ├── outputs.tf
    ├── modules/
    │   ├── s3-backend/
    │   ├── vpc/
    │   ├── ecr/
    │   ├── eks/
    │   ├── jenkins/
    │   └── argo_cd/
    │       └── charts/
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

Потрібні:

- AWS CLI з налаштованою авторизацією в потрібному AWS-акаунті;
- Terraform;
- `kubectl`;
- Docker Desktop, якщо образ збирається вручну;
- Git;
- доступ до GitHub-репозиторію;
- Jenkins та Argo CD, встановлені в EKS.

Перевірте, що AWS CLI авторизований у правильному акаунті:

```powershell
aws sts get-caller-identity
```

## Terraform: створення інфраструктури

### 1. Перше створення backend-ресурсів

S3 bucket і DynamoDB table для Terraform state спочатку мають бути створені. Якщо вони керуються цим самим Terraform-проєктом, перший запуск виконується з вимкненим S3 backend:

1. Тимчасово закоментуйте блок backend у `backend.tf`.
2. Із каталогу `lesson-9` виконайте:

```powershell
terraform init
terraform validate
terraform plan
terraform apply
```

Перед підтвердженням `apply` перегляньте план. Він не повинен містити неочікуваного знищення наявної інфраструктури.

### 2. Перенесення Terraform state до S3

Після успішного створення S3 bucket і DynamoDB table:

1. Розкоментуйте й перевірте конфігурацію S3 backend у `backend.tf`.
2. Переконайтеся, що bucket, регіон, key та таблиця блокувань відповідають створеним ресурсам.
3. Перенесіть state:

```powershell
terraform init -migrate-state
terraform plan
```

У поточній конфігурації використовуються:

- регіон AWS: `us-west-2`;
- S3 bucket для Terraform state: `volodymyr-train-lesson-5`;
- DynamoDB table для блокувань: `terraform-locks`.

### 3. Перевірка інфраструктури

Перевірте ресурси через Terraform:

```powershell
terraform output
```

Основні ресурси цієї конфігурації:

| Ресурс | Значення |
|---|---|
| AWS region | `us-west-2` |
| EKS cluster | `eks-cluster-demo` |
| ECR repository | `lesson-5-ecr` |
| Jenkins namespace | `jenkins` |
| Argo CD namespace | `argocd` |

Підключіть `kubectl` до EKS:

```powershell
aws eks update-kubeconfig --region us-west-2 --name eks-cluster-demo
kubectl get nodes
kubectl get pods --all-namespaces
```

Вузли мають перейти у стан `Ready`. Перевірте Pod-и Jenkins та Argo CD:

```powershell
kubectl get pods -n jenkins
kubectl get pods -n argocd
```

## Jenkins

### Доступ до Jenkins

Знайдіть адресу LoadBalancer:

```powershell
kubectl get svc -n jenkins
```

Відкрийте значення `EXTERNAL-IP` сервісу `jenkins` у браузері з протоколом `http://`.

Ім’я адміністратора за типовою конфігурацією — `admin`. Якщо пароль не збережений окремо, його можна прочитати з Kubernetes secret:

```powershell
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password
```

### Jenkins credentials для GitHub

Pipeline має мати окремий GitHub token із правом запису до репозиторію, щоб оновлювати Helm chart.

Для fine-grained personal access token:

- виберіть репозиторій `Astronaut-08/my-microservice-project`;
- у Repository permissions надайте `Contents: Read and write`.

Збережіть токен у Jenkins:

1. Відкрийте **Manage Jenkins → Credentials → System → Global credentials**.
2. Додайте credential типу **Username with password**.
3. У username укажіть GitHub username, у password — PAT.
4. Встановіть ID `github-token`.

Не вставляйте PAT у `Jenkinsfile`, не додавайте його до Git і не друкуйте в build logs.

### Налаштування Jenkins job

Job `django` має читати Jenkinsfile із Git:

- Definition: `Pipeline script from SCM`;
- SCM: `Git`;
- Repository URL: `https://github.com/Astronaut-08/my-microservice-project.git`;
- Branch: `*/lesson-9`;
- Script Path: `Jenkinsfile`.

Jenkins має використовувати Kubernetes agent у namespace `jenkins`. Для доступу до ECR агент працює під Kubernetes ServiceAccount `jenkins-sa`, якій призначена IAM-роль через EKS IAM Roles for Service Accounts (IRSA).

### Очікувані етапи pipeline

Jenkinsfile у корені репозиторію має виконувати такі кроки:

1. Отримати код із гілки `lesson-9`.
2. Зібрати образ із `docker/django/Dockerfile`, використовуючи `docker/django` як build context.
3. Опублікувати образ у ECR з унікальним тегом, наприклад номером збірки та коротким hash Git commit.
4. Оновити `image.tag` у `lesson-9/charts/django-app/values.yaml`.
5. Запушити зміну Helm chart у гілку `lesson-9`.

Для збірки в Kubernetes використовується Kaniko. Jenkins agent має мати доступ до AWS ECR через IRSA; локальний Docker login на комп’ютері не є заміною правам Jenkins agent-а.

Запустіть job кнопкою **Build Now** та перевірте **Console Output**. Успішна збірка має завершитися без помилок на етапах публікації образу та Git push. У GitHub має з’явитися новий commit із оновленим тегом образу.

## Amazon ECR

Terraform створює ECR-репозиторій `lesson-5-ecr`. Його URL у поточному AWS-акаунті:

```text
516885649085.dkr.ecr.us-west-2.amazonaws.com/lesson-5-ecr
```

Jenkins має пушити версійовані образи в цей репозиторій. Перевірити наявність тегів можна так:

```powershell
aws ecr describe-images `
  --repository-name lesson-5-ecr `
  --region us-west-2 `
  --query "imageDetails[].imageTags[]" `
  --output text
```

Не створюйте окремий ECR repository вручну, якщо ним уже керує Terraform.

## Argo CD та Helm chart

Argo CD Application відстежує:

- Git repository: `https://github.com/Astronaut-08/my-microservice-project.git`;
- гілку: `lesson-9`;
- шлях до chart: `lesson-9/charts/django-app`;
- Kubernetes namespace застосунку: `default`.

Після того як Jenkins запушить зміну `image.tag`, Argo CD має побачити новий commit і синхронізувати застосунок. Перевірте:

```powershell
kubectl get applications -n argocd
kubectl describe application django-app -n argocd
```

Бажаний результат:

- Sync status: `Synced`;
- Health status: `Healthy`.

Якщо Argo CD показує стару ревізію, перевірте, що commit справді запушений у гілку `lesson-9`, яку відстежує Application.

## Перевірка Django

Перевірте стан Deployment і Pod-ів:

```powershell
kubectl get deployment,service,hpa -n default
kubectl get pods -n default
kubectl rollout status deployment/django-app-django -n default --timeout=120s
```

Для локальної перевірки через port-forward:

```powershell
kubectl port-forward -n default service/django-app-django 8000:80
```

Поки команда працює, відкрийте `http://localhost:8000` у браузері. Port-forward активний лише до завершення цієї команди.

Для тимчасової демонстрації використовується SQLite: SQLite у файловій системі Pod-а не є постійним сховищем і не замінює налаштовану PostgreSQL-базу для повного застосунку.

## Типові проблеми

### Jenkins job успішний, але етапи збірки пропущені

Якщо в логах є `empty changelog` або `skipped due to when conditional`, pipeline не бачить змін, які запускають етапи. Перевірте checkout і умови `when` у Jenkinsfile. Для перевірки внесіть і запуште новий commit у `Jenkinsfile` або `docker/django/`.

### `ImagePullBackOff`

Перевірте адресу і тег образу в Helm values, а також наявність цього тегу в ECR:

```powershell
kubectl describe pod -n default <ім'я-pod>
aws ecr describe-images --repository-name lesson-5-ecr --region us-west-2 --query "imageDetails[].imageTags[]" --output text
```

### Jenkins agent не запускається

Перевірте Pod агента та його події:

```powershell
kubectl get pods -n jenkins -o wide
kubectl describe pod -n jenkins <ім'я-agent-pod>
```

Перевірте, що образи контейнерів агента існують, доступні для pull, а ServiceAccount агента — `jenkins-sa`.

### Jenkins controller `Pending`

Перевірте події Pod-а:

```powershell
kubectl describe pod jenkins-0 -n jenkins
kubectl get nodes -L topology.kubernetes.io/zone
kubectl get pvc -n jenkins -o wide
```

Jenkins використовує EBS PersistentVolume. Такий диск прив’язаний до AWS availability zone, тому Jenkins Pod може запускатися лише на вузлі в сумісній зоні.

### HPA не знаходить Deployment

Переконайтеся, що `spec.scaleTargetRef.name` у шаблоні HPA відповідає фактичній назві Deployment. Для релізу `django-app` назва Deployment у цій конфігурації — `django-app-django`.

## Витрати та очищення

EKS, EC2 worker nodes, NAT Gateway, LoadBalancer, EBS volumes та інші AWS-ресурси можуть створювати витрати, доки існують.

Після завершення навчання перевірте Terraform plan перед очищенням. Знищення інфраструктури видалить кластер і його Kubernetes-ресурси; видалення EBS/PVC може призвести до втрати даних Jenkins. S3 bucket, який використовується як Terraform backend, не можна видаляти до безпечного перенесення або резервування state.

## Схема CI/CD

```text
GitHub (lesson-9)
       │
       ▼
Jenkins Pipeline
  ├─ збирає Docker image
  ├─ публікує image у Amazon ECR
  └─ оновлює image.tag у Helm chart та пушить commit у GitHub
       │
       ▼
Argo CD в EKS
  ├─ відстежує Git repository
  └─ синхронізує Helm chart у Kubernetes
       │
       ▼
Django Deployment у EKS
```