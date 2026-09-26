# AIWA Backend Hosting Provider Guide

This guide explains what type of hosting provider is suitable for the AIWA backend and which options are recommended for the first production launch.

The AIWA backend is a Spring Boot API that needs:

```text
Java / Spring Boot
Docker
PostgreSQL
Redis
Nginx
HTTPS
Persistent storage
```

Because of this, do not use shared hosting or cPanel-only hosting. Use a VPS or cloud server.

## Recommended Hosting Type

Best first production setup:

```text
VPS / Cloud VM
Ubuntu 22.04 or 24.04
Docker Compose
Nginx reverse proxy
Let's Encrypt HTTPS
```

This allows you to run:

```text
Backend container
PostgreSQL container
Redis container
Nginx on host
```

## Minimum Server Specs

For first live version:

```text
CPU: 2 vCPU minimum
RAM: 4 GB minimum
Disk: 80 GB SSD minimum
OS: Ubuntu 22.04 or 24.04 LTS
```

Recommended:

```text
CPU: 4 vCPU
RAM: 8 GB
Disk: 100 GB SSD
```

Use the recommended size if you expect real traffic, many provider searches, uploads, or admin activity.

## Provider Options

### Option 1: Hetzner Cloud

Best for:

```text
Lowest cost
Good performance
Docker Compose deployment
European users
```

Recommended server:

```text
Ubuntu 22.04/24.04
2-4 vCPU
4-8 GB RAM
80+ GB SSD
```

Pros:

```text
Very good price/performance
Stable VPS
Good for Docker
Good for first production launch
```

Cons:

```text
Less beginner-friendly than DigitalOcean
Managed database options may be less simple depending on region/setup
```

Choose Hetzner if price/performance matters most.

### Option 2: DigitalOcean

Best for:

```text
Easy UI
Beginner-friendly cloud setup
Good documentation
Managed PostgreSQL / Redis options
```

Recommended Droplet:

```text
2 vCPU
4 GB RAM
80 GB disk
Ubuntu 22.04/24.04
```

Pros:

```text
Easy dashboard
Good docs
Simple firewall and DNS tools
Managed databases available
Good for first-time deployment
```

Cons:

```text
Usually more expensive than Hetzner for the same server size
```

Choose DigitalOcean if you want the easiest deployment experience.

### Option 3: AWS Lightsail

Best for:

```text
Simple AWS server
Teams already using AWS
Predictable monthly pricing
```

Pros:

```text
Simpler than EC2
Good AWS integration path later
Stable platform
```

Cons:

```text
AWS networking and permissions can still be confusing
Less simple than DigitalOcean for beginners
```

Choose AWS Lightsail if the client already prefers AWS.

### Option 4: Azure VM

Best for:

```text
Companies already using Microsoft Azure
Enterprise environments
```

Pros:

```text
Good enterprise support
Integrates with Azure services
```

Cons:

```text
More configuration
Can be more expensive
Not the simplest first deployment option
```

Choose Azure if the business already uses Microsoft/Azure.

## Best Recommendation

For your current backend, the best first production choice is:

```text
Hetzner Cloud if you want best price/performance
DigitalOcean if you want easiest setup
```

Recommended first setup:

```text
1 VPS
Ubuntu 22.04/24.04
Docker Compose
Nginx
Let's Encrypt HTTPS
PostgreSQL container
Redis container
AIWA backend container
Daily PostgreSQL backups
Health monitoring
```

## Not Recommended

Do not use:

```text
Shared hosting
cPanel-only hosting
Static hosting
Firebase Hosting only
Netlify only
Vercel only
Basic PHP hosting
```

These are not suitable because the backend needs Java, Docker, PostgreSQL, Redis, and a long-running server process.

## When To Use Managed PostgreSQL And Redis

For the first launch, running PostgreSQL and Redis inside Docker Compose is acceptable if backups are configured.

Use managed PostgreSQL and managed Redis later when:

```text
The app has real paying users
Downtime is expensive
You need automatic backups
You need easier scaling
You do not want to manage database upgrades
```

Better future architecture:

```text
Backend container on VPS
Managed PostgreSQL
Managed Redis
Cloud object storage
Monitoring
CI/CD
```

## Provider Decision Table

```text
Need lowest cost        -> Hetzner
Need easiest setup      -> DigitalOcean
Need AWS ecosystem      -> AWS Lightsail
Need Microsoft/Azure    -> Azure VM
Need serious scaling    -> Managed DB + Managed Redis + load balancer
```

## Final Choice

Recommended for AIWA first production:

```text
DigitalOcean Droplet 2 vCPU / 4 GB RAM
or
Hetzner Cloud 2-4 vCPU / 4-8 GB RAM
```

Use Docker Compose with:

```text
docker-compose.prod.yml
.env
Nginx
HTTPS
Daily backups
Health monitoring
```

Then deploy using the steps in:

```text
PRODUCTION_ENVIRONMENT_GUIDE.md
PRODUCTION_RUN.md
```
