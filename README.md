# Library API

Лабораторна робота № 2. Масштабування, моніторинг і кешування API в AWS.

```text
CloudLab-Ihor/
├── app/                  FastAPI та кеш
├── bootstrap/            Бюджет AWS
├── infra/                Terraform
├── loadtest/             Сценарій k6
├── docs/
│   ├── ALERTS.md
│   ├── AUTOSCALING.md
│   ├── CACHE.md
│   ├── LOADTEST.md
│   ├── public/
│   │   ├── no_cache/     Скриншоти першого прогону
│   │   ├── cache/        Скриншоти другого прогону
│   │   └── local/        Локальна перевірка
│   └── evidence/         Результати k6 у JSON
└── compose.yaml
```

## Запуск

У локальному `.env` задайте `DB_PASSWORD`.

```powershell
docker compose up --build -d
Invoke-RestMethod http://127.0.0.1:8000/health
```

[Локальний Swagger](http://127.0.0.1:8000/docs). Адреса AWS доступна через `terraform -chdir=infra output -raw app_url`.

## Лабораторна № 2

- [Масштабування ECS і панель CloudWatch](docs/AUTOSCALING.md)
- [Сповіщення CloudWatch та листи SNS](docs/ALERTS.md)
- [Сценарій і результати k6](docs/LOADTEST.md)
- [Порівняння кешу](docs/CACHE.md)
