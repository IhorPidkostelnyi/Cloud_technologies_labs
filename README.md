Lab1


- [Публічна адреса](http://cloud-lab1-ihor-alb-1989241011.eu-north-1.elb.amazonaws.com)
- [Swagger — документація API](http://cloud-lab1-ihor-alb-1989241011.eu-north-1.elb.amazonaws.com/docs)
- [Перевірка стану API та бази](http://cloud-lab1-ihor-alb-1989241011.eu-north-1.elb.amazonaws.com/health)

## Структура проєкту

```text
CloudLab-Ihor
├─ app
│  ├─ Dockerfile                  # Збірка контейнера застосунку
│  ├─ .dockerignore               # Виключення зайвих файлів з образу
│  ├─ requirements.txt            # Залежності Python
│  ├─ main.py                     # Запуск API та обробка запитів
│  ├─ database.py                 # Підключення до PostgreSQL
│  ├─ models.py                   # Моделі авторів і книжок
│  └─ schemas.py                  # Перевірка даних запитів і відповідей
├─ bootstrap
│  ├─ main.tf                     # Бюджет AWS
│  ├─ sns.tf                      # Сповіщення про витрати на email
│  ├─ .terraform.lock.hcl         # Фіксація версій провайдерів
│  └─ terraform.tfvars.example    # Приклад налаштування email
├─ infra
│  ├─ providers.tf                # Підключення Terraform-провайдерів
│  ├─ variables.tf                # Змінні конфігурації
│  ├─ network.tf                  # Мережа, підмережі та маршрути
│  ├─ security.tf                 # Групи безпеки та правила доступу
│  ├─ rds.tf                      # База PostgreSQL в Amazon RDS
│  ├─ ecr.tf                      # Реєстр Docker-образів
│  ├─ image.tf                    # Збірка й публікація початкового образу
│  ├─ ecs.tf                      # Запуск контейнера в ECS Fargate
│  ├─ alb.tf                      # Балансувальник навантаження
│  ├─ iam.tf                      # Ролі та дозволи AWS
│  ├─ github_oidc.tf              # OIDC для GitHub Actions
│  ├─ outputs.tf                  # Адреса API та назви ресурсів
│  ├─ .terraform.lock.hcl         # Фіксація версій провайдерів
│  └─ terraform.tfvars.example    # Приклад налаштувань інфраструктури
├─ .github
│  └─ workflows
│     └─ deploy.yml               # Workflow для розгортання з GitHub
├─ compose.yaml                   # Локальний запуск API та PostgreSQL
├─ .env.example                   # Приклад змінних середовища
├─ .gitignore                     # Виключення секретів і службових файлів
├─ .gitattributes                 # Налаштування кінців рядків
└─ README.md                      # Опис проєкту
```

Локальний запуск

docker compose up --build -d


API: http://localhost:8000, Swagger: http://localhost:8000/docs.

Дані бази зберігаються у volume та залишаються після `docker compose down`.
