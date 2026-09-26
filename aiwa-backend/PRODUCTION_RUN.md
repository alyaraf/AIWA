# AIWA Backend Production Run

AIWA is a Spring Boot application with embedded Tomcat. You do not need to deploy it into an external Tomcat server. The recommended production options are:

1. Docker Compose: backend container + PostgreSQL + Redis.
2. Executable jar behind Nginx or a cloud load balancer.

## Option 1: Docker Compose

Copy the example environment file and fill real values:

```powershell
Copy-Item .env.example .env
notepad .env
```

Run:

```powershell
docker compose -f docker-compose.prod.yml up --build -d
```

Check:

```powershell
docker compose -f docker-compose.prod.yml ps
curl http://localhost:8080/api/actuator/health
```

## Option 2: Executable Jar

Run PostgreSQL and Redis first, then set environment variables:

```powershell
$env:SPRING_PROFILES_ACTIVE="prod"
$env:SPRING_DATASOURCE_URL="jdbc:postgresql://YOUR_DB_HOST:5432/aiwa_db"
$env:DB_USERNAME="aiwa_user"
$env:DB_PASSWORD="strong-db-password"
$env:REDIS_HOST="YOUR_REDIS_HOST"
$env:REDIS_PORT="6379"
$env:JWT_SECRET="very-long-random-secret"
$env:CORS_ALLOWED_ORIGINS="https://yourdomain.com"
$env:SMS_PROVIDER="external"
$env:SMS_API_URL="https://sms-provider.example/send"
$env:SMS_API_KEY="sms-api-key"
$env:ADMIN_EMAIL="admin@yourdomain.com"
$env:ADMIN_PASSWORD="very-strong-admin-password"
java -jar target\aiwa-backend-1.0.0.jar
```

## Nginx Example

Use Nginx or a load balancer for HTTPS and reverse proxy:

```nginx
server {
    listen 443 ssl;
    server_name api.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

## Important

Never commit `.env` to Gitblit. Commit `.env.example`, `docker-compose.prod.yml`, and this document only.
