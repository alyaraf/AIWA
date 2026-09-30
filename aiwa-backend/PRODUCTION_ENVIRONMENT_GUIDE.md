# AIWA Backend Production Environment Guide

This guide explains how to prepare, configure, run, and maintain the AIWA backend in a stable production environment.

The backend is a Spring Boot REST API. It already includes embedded Tomcat, so you do not need to deploy it into an external Tomcat server. The recommended production setup is Docker Compose behind Nginx with HTTPS.

This is the single deploy guide for the backend (it replaces the old PRODUCTION_RUN.md and HOSTING_PROVIDER_GUIDE.md). To run the backend **and** the admin panel behind Caddy with automatic HTTPS instead, use the full stack in `deploy/` at the repo root (see `docs/release.md`).

## 1. Production Architecture

Recommended first production architecture:

```text
Mobile App / Web App
        |
        v
https://api.yourdomain.com
        |
        v
Nginx reverse proxy + SSL
        |
        v
AIWA Spring Boot backend container
        |
        +--> PostgreSQL database
        |
        +--> Redis
```

PostgreSQL is the source of truth for users, bookings, providers, reviews, notifications, settlement, and admin data.

Redis is used for OTP expiry, rate limits, JWT blacklist, provider search cache, notification event stream, and scheduler locks.

## 2. Server Requirements

Minimum server for first live version:

```text
OS: Ubuntu 22.04 or 24.04 LTS
CPU: 2 cores minimum, 4 recommended
RAM: 4 GB minimum, 8 GB recommended
Disk: 80 GB SSD minimum
Network: Public IP
```

Install on the server:

```bash
sudo apt update
sudo apt install -y git curl ufw nginx
```

Install Docker:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```

Log out and log in again after adding your user to the Docker group.

Install Docker Compose plugin if needed:

```bash
docker compose version
```

### Choosing a host

Any VPS that runs Docker works; shared, cPanel, PHP or static hosting (Netlify, Vercel, Firebase Hosting) does not, because the backend needs Java, PostgreSQL, Redis and a long-running process.

| Need | Choice |
|------|--------|
| Lowest cost | Hetzner Cloud, 2–4 vCPU / 4–8 GB |
| Easiest setup | DigitalOcean Droplet, 2 vCPU / 4 GB |
| AWS or Azure already in use | AWS Lightsail or an Azure VM of the same size |
| Real paying users, downtime is expensive | Managed PostgreSQL + managed Redis, backend container on the VPS |

PostgreSQL and Redis inside Docker Compose are fine for the first launch **only with the daily backups in section 11**.

## 3. Domain And DNS

Create a DNS record:

```text
Type: A
Name: api
Value: YOUR_SERVER_PUBLIC_IP
```

Example:

```text
api.yourdomain.com -> 123.123.123.123
```

## 4. Clone From Gitblit

On the production server:

```bash
git clone <your-gitblit-repo-url> aiwa-backend
cd aiwa-backend
```

Gitblit should store code only. Never push real production passwords, API keys, JWT secrets, or `.env` files.

## 5. Production Environment Variables

Create the real production `.env` file from the example:

```bash
cp .env.example .env
nano .env
```

Example `.env`:

```env
SPRING_PROFILES_ACTIVE=prod
SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/aiwa_db
DB_USERNAME=aiwa_user
DB_PASSWORD=change-this-db-password
REDIS_HOST=redis
REDIS_PORT=6379
JWT_SECRET=change-this-to-a-long-random-production-secret
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
SMS_PROVIDER=external
SMS_API_URL=https://sms-provider.example/send
SMS_API_KEY=change-this-sms-api-key
SMS_SENDER=AIWA
ADMIN_EMAIL=admin@yourdomain.com
ADMIN_PHONE=
ADMIN_PASSWORD=change-this-admin-password
ADMIN_FULL_NAME=AIWA Admin
POSTGRES_DB=aiwa_db
POSTGRES_USER=aiwa_user
POSTGRES_PASSWORD=change-this-db-password
```

Important rules:

```text
JWT_SECRET must be changed.
DB_PASSWORD must be changed.
SMS_PROVIDER must not be dev-log in production.
CORS_ALLOWED_ORIGINS must be exact domains, not *.
.env must never be committed to Gitblit.
```

The application has a production guard. If you run with `SPRING_PROFILES_ACTIVE=prod` and unsafe values, the backend will refuse to start.

## 5.1 First Admin User

The public registration API cannot create admin users.

The first admin is created automatically at startup when:

```text
No admin user exists in the database
ADMIN_EMAIL or ADMIN_PHONE is set
ADMIN_PASSWORD is set and at least 12 characters
```

Add this to `.env` before the first production start:

```env
ADMIN_EMAIL=admin@yourdomain.com
ADMIN_PHONE=
ADMIN_PASSWORD=very-strong-admin-password
ADMIN_FULL_NAME=AIWA Admin
```

Start the backend once. The admin user will be created. After confirming login works, you may remove `ADMIN_PASSWORD` from `.env` and restart. The existing admin will remain in PostgreSQL.

Login from Swagger or the app:

```http
POST /api/auth/login
```

Body:

```json
{
  "identifier": "admin@yourdomain.com",
  "password": "very-strong-admin-password"
}
```

After the first admin logs in, create additional admins through:

```http
POST /api/admin/users/admins
Authorization: Bearer <admin-access-token>
```

Body:

```json
{
  "fullName": "Second Admin",
  "email": "admin2@yourdomain.com",
  "phone": null,
  "password": "another-strong-admin-password"
}
```

Admin passwords must be at least 12 characters.

## 6. Run With Docker Compose

Use the production compose file:

```bash
docker compose -f docker-compose.prod.yml up --build -d
```

Check running containers:

```bash
docker compose -f docker-compose.prod.yml ps
```

Check backend health:

```bash
curl http://localhost:8080/api/actuator/health
```

Expected response:

```json
{"status":"UP"}
```

View logs:

```bash
docker compose -f docker-compose.prod.yml logs -f app
```

Restart app:

```bash
docker compose -f docker-compose.prod.yml restart app
```

Stop all services:

```bash
docker compose -f docker-compose.prod.yml down
```

Do not use `-v` with `down` in production unless you intentionally want to delete database and Redis volumes.

### Without Docker (executable jar)

Run PostgreSQL and Redis first, set the same variables as in section 5 in the environment, then:

```bash
SPRING_PROFILES_ACTIVE=prod java -jar target/aiwa-backend-1.0.0.jar
```

## 7. Nginx Reverse Proxy

Create an Nginx config:

```bash
sudo nano /etc/nginx/sites-available/aiwa-api
```

Add:

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable it:

```bash
sudo ln -s /etc/nginx/sites-available/aiwa-api /etc/nginx/sites-enabled/aiwa-api
sudo nginx -t
sudo systemctl reload nginx
```

Now test:

```bash
curl http://api.yourdomain.com/api/actuator/health
```

## 8. HTTPS With Let's Encrypt

Install Certbot:

```bash
sudo apt install -y certbot python3-certbot-nginx
```

Generate SSL certificate:

```bash
sudo certbot --nginx -d api.yourdomain.com
```

Test HTTPS:

```bash
curl https://api.yourdomain.com/api/actuator/health
```

Certbot normally installs auto-renewal. Check it:

```bash
sudo systemctl status certbot.timer
```

## 9. Firewall

Allow only SSH, HTTP, and HTTPS publicly:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
sudo ufw status
```

Do not expose PostgreSQL or Redis publicly.

In `docker-compose.prod.yml`, PostgreSQL and Redis are not published to public ports. Keep them internal.

## 10. Database Stability

Production uses:

```yaml
spring.jpa.hibernate.ddl-auto=validate
spring.flyway.enabled=true
```

This means Hibernate will not modify the database automatically in production.

Future schema changes should be added as Flyway migrations:

```text
src/main/resources/db/migration/V2__add_new_table.sql
src/main/resources/db/migration/V3__add_new_column.sql
```

Migration naming rules:

```text
V<number>__description.sql
Two underscores after version number
Never edit an already-applied production migration
Add a new migration instead
```

## 11. Database Backups

Create backup folder:

```bash
mkdir -p ~/aiwa-backups
```

Manual backup:

```bash
docker exec aiwa_postgres_prod pg_dump -U aiwa_user aiwa_db > ~/aiwa-backups/aiwa_$(date +%F_%H-%M).sql
```

Restore backup:

```bash
cat ~/aiwa-backups/backup-file.sql | docker exec -i aiwa_postgres_prod psql -U aiwa_user aiwa_db
```

Daily backup cron:

```bash
crontab -e
```

Add:

```cron
0 2 * * * docker exec aiwa_postgres_prod pg_dump -U aiwa_user aiwa_db > /home/ubuntu/aiwa-backups/aiwa_$(date +\%F).sql
```

Recommended later: upload backups to external storage like S3, Backblaze, Cloudflare R2, or another server.

## 12. Redis Stability

Redis is configured with append-only persistence:

```text
redis-server --appendonly yes
```

Redis is not the source of truth. If Redis is lost:

```text
Users/bookings/providers remain safe in PostgreSQL.
Temporary OTPs expire/disappear.
Login rate counters reset.
JWT blacklist disappears.
Provider search cache resets.
Notification stream pending events may be lost.
```

For higher production reliability later, use managed Redis.

## 13. Health And Monitoring

Health endpoint:

```text
https://api.yourdomain.com/api/actuator/health
```

Use a monitoring tool such as:

```text
UptimeRobot
Better Stack
Grafana
Prometheus
Sentry
Cloud provider monitoring
```

Minimum checks:

```text
Backend health is UP
Disk space is not full
Docker containers are running
Database backups are being created
Error logs are monitored
SSL certificate is valid
```

Check logs:

```bash
docker compose -f docker-compose.prod.yml logs -f app
docker compose -f docker-compose.prod.yml logs -f postgres
docker compose -f docker-compose.prod.yml logs -f redis
```

## 14. Deployment Process

Simple deployment:

```bash
cd aiwa-backend
git pull
docker compose -f docker-compose.prod.yml up --build -d
docker compose -f docker-compose.prod.yml ps
curl https://api.yourdomain.com/api/actuator/health
```

Rollback simple approach:

```bash
git log --oneline
git checkout <previous-good-commit>
docker compose -f docker-compose.prod.yml up --build -d
```

Better later: use CI/CD and tagged releases.

## 15. Production Security Checklist

Before going live:

```text
[ ] JWT_SECRET changed
[ ] DB password changed
[ ] SMS provider configured
[ ] CORS only allows real frontend domains
[ ] HTTPS enabled
[ ] Firewall enabled
[ ] Postgres not public
[ ] Redis not public
[ ] .env not committed
[ ] Health endpoint works
[ ] Backups tested
[ ] Swagger protected or disabled if required
[ ] Logs checked
```

## 16. Useful URLs

Local server:

```text
http://localhost:8080/api/actuator/health
http://localhost:8080/api/swagger-ui.html
```

Production:

```text
https://api.yourdomain.com/api/actuator/health
https://api.yourdomain.com/api/swagger-ui.html
```

## 17. Important Notes

Use Gitblit for source code only.

Do not commit:

```text
.env
production passwords
JWT secrets
SMS keys
database dumps
uploaded user files
logs
```

Use Docker Compose or the executable jar. External Tomcat is not needed because Spring Boot already includes embedded Tomcat.
