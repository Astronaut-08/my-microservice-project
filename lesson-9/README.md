Структура проекту виглядає так 

```sh
Progect/
│
├── main.tf                  # Головний файл для підключення модулів
├── backend.tf               # Налаштування бекенду для стейтів (S3 + DynamoDB
├── outputs.tf               # Загальні виводи ресурсів
│
├── modules/                 # Каталог з усіма модулями
│   ├── s3-backend/          # Модуль для S3 та DynamoDB
│   │   ├── s3.tf            # Створення S3-бакета
│   │   ├── dynamodb.tf      # Створення DynamoDB
│   │   ├── variables.tf     # Змінні для S3
│   │   └── outputs.tf       # Виведення інформації про S3 та DynamoDB
│   │
│   ├── vpc/                 # Модуль для VPC
│   │   ├── vpc.tf           # Створення VPC, підмереж, Internet Gateway
│   │   ├── routes.tf        # Налаштування маршрутизації
│   │   ├── variables.tf     # Змінні для VPC
│   │   └── outputs.tf  
│   ├── ecr/                 # Модуль для ECR
│   │   ├── ecr.tf           # Створення ECR репозиторію
│   │   ├── variables.tf     # Змінні для ECR
│   │   └── outputs.tf       # Виведення URL репозиторію
│   │
│   ├── eks/                      # Модуль для Kubernetes кластера
│   │   ├── eks.tf                # Створення кластера
│   │   ├── aws_ebs_csi_driver.tf # Встановлення плагіну csi drive
│   │   ├── variables.tf     # Змінні для EKS
│   │   └── outputs.tf       # Виведення інформації про кластер
│   │
│   ├── jenkins/             # Модуль для Helm-установки Jenkins
│   │   ├── jenkins.tf       # Helm release для Jenkins
│   │   ├── variables.tf     # Змінні (ресурси, креденшели, values)
│   │   ├── providers.tf     # Оголошення провайдерів
│   │   ├── values.yaml      # Конфігурація jenkins
│   │   └── outputs.tf       # Виводи (URL, пароль адміністратора)
│   │ 
│   └── argo_cd/             # ✅ Новий модуль для Helm-установки Argo CD
│       ├── jenkins.tf       # Helm release для Jenkins
│       ├── variables.tf     # Змінні (версія чарта, namespace, repo URL тощо)
│       ├── providers.tf     # Kubernetes+Helm.  переносимо з модуля jenkins
│       ├── values.yaml      # Кастомна конфігурація Argo CD
│       ├── outputs.tf       # Виводи (hostname, initial admin password)
│		    └──charts/                  # Helm-чарт для створення app'ів
│ 	 	    ├── Chart.yaml
│	  	    ├── values.yaml          # Список applications, repositories
│			    └── templates/
│		        ├── application.yaml
│		        └── repository.yaml
├── charts/
│   └── django-app/
│       ├── templates/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── configmap.yaml
│       │   └── hpa.yaml
│       ├── Chart.yaml
│       └── values.yaml     # ConfigMap зі змінними середовища
```

Команди для ініціалізації та запуску проекту

* спочатку закоментуйте весь код в backend.tf потім запустіть дану команду
```sh
terraform init
terraform plan
terraform apply
```

* Тепер розкоментуйте код в файлі backend.tf і запустіть наступні команди 
```sh
terraform init -migrate-state
```

* Налаштування kubectl
```sh
aws sts get-caller-identity
aws eks update-kubeconfig --region us-west-2 --name volodymyr-train-lesson-5
# Ці команди для перевірки статусу
kubectl get nodes
kubectl get pods --all-namespaces
```

* Створення репозиторію і завантаження образу (так як я роблю на віндовсі, ps перемикаю на cmd для того щоб спрацювала команда) замість `<YOUR_ACCOUNT_ID>` потрібно ввести id акаунту на aws console
```sh
cmd
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <YOUR_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com
exit
aws ecr create-repository --repository-name django-app --region us-west-2
# Дані переходимо вдиректорію з DockerFile
docker build -t django-app .
docker tag django-app:latest <YOUR_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/django-app:latest
docker push <YOUR_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/django-app:latest
```

* Створення Helm чартів і запуск відбувається:
```sh
# перебуваючи в папці lesson-7\charts\django-app
.\helm install django-app .
```

# Пояснення щодо модулів проекту
1. S3-Backend - зберігає стан terraform. Створює файл json terraform.tfstate. Через DynamoDB дозволяє блокувати apply інших користувачів доки якийсь з них виконує apply.
2. VPC - власна віртуальна мережа AWS у якій живуть наші сервіси. В ній є публічі субмережі та приватні. Варто зазначити, що публічні мережі ходять в інтернет через IGW і доступні ззовні, а приватні лише через NAT і ззовні недоступні.
3. ECR - приватний реєстр для docker образів всередині нашого акаунту. Тут створено репозиторій для образів мікросервісу. Додано політику доступу до репозиторію взяту через ідентифікатор акаунту. 
