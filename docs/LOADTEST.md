# Навантажувальне тестування

Сценарій [library.js](../loadtest/library.js) за цикл створює книгу, п’ять разів читає список, тричі читає книгу за ID й один раз читає автора. Між циклами пауза 0,5 с.

## Запуск

Для порівняння вимкнути розклад і почати з однієї задачі ECS. Перший тест запускати з `books_cache_enabled = false`.

```powershell
$Url = terraform -chdir=infra output -raw app_url
& .\loadtest\run.ps1 -Url $Url -Vus 12 -Cache off
& .\loadtest\wait-min.ps1
```

Увімкнути `books_cache_enabled`, дочекатися завершення [оновлення ECS](AUTOSCALING.md#оновлення-ecs) і повернення до однієї задачі, потім запустити другий тест.

```powershell
& .\loadtest\run.ps1 -Url $Url -Vus 12 -Cache on
& .\loadtest\wait-min.ps1
```

| Фаза | Тривалість | VU |
| --- | ---: | --- |
| Наростання | 3 хв | 0 → 11 за 1 хв, потім до 12 |
| Стале навантаження | 5 хв | 12 |
| Спад | 2 хв | 12 → 0 |
| Спостереження | 4 хв | 0, без HTTP-запитів |



## Вибір N

Проба з 8 VU дала 48,74 запиту/с і пік CPU 56,41%. ECS лишився на одній задачі. З 12 VU задача спочатку додалась приблизно через 50 с після початку спаду. У фінальних тестах швидше підняли навантаження на першій хвилині й залишили 12 VU в обох режимах.

[Калібрування 8 VU](evidence/k6-redis-off-calibration-8vu.json) · [Панель CloudWatch](public/redis-off-calibration-8vu/dashboard.png) · [Метрики RDS](public/redis-off-calibration-8vu/rds.png) · [Калібрування 12 VU](evidence/k6-redis-off-calibration-12vu.json)

## Результати

| Метрика | Без кешу | З Redis |
| --- | ---: | ---: |
| Запити | 47 970 | 30 850 |
| Запитів/с | 79,84 | 51,44 |
| Помилки | 0% | 0% |
| p50, мс | 46,01 | 90,41 |
| p95, мс | 202,72 | 447,75 |
| p99, мс | 513,16 | 810,91 |

[JSON без кешу](evidence/k6-redis-off.json) · [JSON з Redis](evidence/k6-redis-on.json)

## Попередні прогони

[Без кешу](evidence/k6-off.json) · [З процесним кешем](evidence/k6-on.json) · [Локальна перевірка API](public/local/health.png)
