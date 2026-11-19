variable "name" {
  description = "Назва інстансу або кластера"
  type        = string
}

variable "engine" {
  type        = string
  default     = "postgres"
  description = "Engine для звичайного RDS instance, наприклад postgres або mysql."
}

variable "engine_cluster" {
  type        = string
  default     = "aurora-postgresql"
  description = "Engine Aurora-кластера, наприклад aurora-postgresql або aurora-mysql."
}

variable "aurora_instance_count" {
  type        = number
  default     = 2 # 1 primary + 1 replica
  description = "Кількість інстансів Aurora-кластера: writer і, за потреби, reader."
}
variable "engine_version" {
  type        = string
  default     = "14.7"
  description = "Версія engine для звичайного RDS instance."
}

variable "instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "Клас обчислювальної інстанції RDS або Aurora, наприклад db.t3.micro."
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Обсяг диска у GiB для звичайного RDS instance; для Aurora не використовується."
}

variable "db_name" {
  type        = string
  description = "Назва початкової бази даних."
}

variable "username" {
  type        = string
  description = "Ім’я головного користувача бази даних."
}

variable "password" {
  type        = string
  sensitive   = true
  description = "Пароль головного користувача бази даних."
}

variable "vpc_id" {
  type        = string
  description = "ID VPC, де створюється база та її security group."
}

variable "subnet_private_ids" {
  type        = list(string)
  description = "ID приватних підмереж для DB subnet group."
}

variable "subnet_public_ids" {
  type        = list(string)
  description = "ID публічних підмереж для DB subnet group, якщо база публічно доступна."
}

variable "publicly_accessible" {
  type        = bool
  default     = false
  description = "Чи буде database instance доступний з публічної мережі."
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "Чи вмикати Multi-AZ для звичайного RDS instance."
}

variable "parameters" {
  type        = map(string)
  default     = {}
  description = "Параметри, що застосовуються до parameter group бази даних."
}

variable "use_aurora" {
  type        = bool
  default     = false
  description = "Якщо true, створює Aurora cluster; інакше — звичайний RDS instance."
}

variable "backup_retention_period" {
  type        = number
  default     = 7
  description = "Кількість днів зберігання автоматичних резервних копій."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Додаткові теги AWS-ресурсів модуля."
}

variable "parameter_group_family_aurora" {
  type        = string
  default     = "aurora-postgresql15"
  description = "Сімейство параметрів Aurora, сумісне з версією її engine."
}
variable "engine_version_cluster" {
  type        = string
  default     = "15.3"
  description = "Версія engine для Aurora-кластера."
}
variable "parameter_group_family_rds" {
  type        = string
  default     = "postgres15"
  description = "Сімейство параметрів звичайного RDS, сумісне з версією engine."
}

variable "db_port" {
  type        = number
  default     = 5432
  description = "Мережевий порт бази даних."
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "CIDR-діапазони, яким дозволено підключатися до бази даних."
}

variable "skip_final_snapshot" {
  description = "Пропускати фінальний snapshot під час видалення бази; true може призвести до втрати даних."
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Назва фінального snapshot, потрібна коли skip_final_snapshot дорівнює false."
  type        = string
  default     = null
}