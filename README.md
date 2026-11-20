
```text
CloudLab-Ihor/
├── app/                  FastAPI, Redis і PostgreSQL
├── bootstrap/            Бюджет AWS
├── infra/                Terraform
├── loadtest/             Сценарій k6
├── docs/
│   ├── ALERTS.md
│   ├── AUTOSCALING.md
│   ├── CACHE.md
│   ├── IDEMPOTENCY.md
│   ├── LOADTEST.md
│   ├── SCHEDULE.md
│   ├── public/
│   │   ├── redis-off/   Фінальний прогін із вимкненим кешем
│   │   ├── redis-on/    Фінальний прогін зі спільним Redis
│   │   ├── aws/         Деплой, сповіщення та розклад
│   │   └── local/       Локальні перевірки
│   └── evidence/        Вимірювання k6, CloudWatch і RDS
└── compose.yaml
```


## AWS


```powershell
terraform -chdir=infra init
terraform -chdir=infra plan
terraform -chdir=infra apply
$Url = terraform -chdir=infra output -raw app_url
Invoke-RestMethod "$Url/health"
```

У листі від Amazon SNS підтвердьте підписку на тему `cloud-lab1-ihor-load-alerts`.


## Лабораторна № 2

- [Масштабування ECS і панель CloudWatch](docs/AUTOSCALING.md)
- [Сповіщення CloudWatch та листи SNS](docs/ALERTS.md)
- [Сценарій і результати k6](docs/LOADTEST.md)
- [Порівняння кешу](docs/CACHE.md)
- [Ідемпотентність створення книги](docs/IDEMPOTENCY.md)
- [Денний і нічний розклад ECS](docs/SCHEDULE.md)
