# AIWA Backend – Spring Boot REST API

> Location-based service booking application backend.

---

## Tech Stack

| Layer        | Technology                          |
|--------------|-------------------------------------|
| Language     | Java 17                             |
| Framework    | Spring Boot 3.2                     |
| Security     | Spring Security + JWT (JJWT 0.11)   |
| Database     | PostgreSQL 16                       |
| ORM          | Spring Data JPA / Hibernate         |
| Docs         | SpringDoc OpenAPI 3 (Swagger UI)    |
| Build        | Maven 3.9                           |
| Container    | Docker + Docker Compose             |

---

## Project Structure

```
src/main/java/com/aiwa/
├── AiwaApplication.java
├── config/
│   ├── SecurityConfig.java       # CORS, JWT filter chain, role rules
│   └── OpenApiConfig.java        # Swagger / Bearer auth setup
├── controller/
│   ├── AuthController.java       # POST /auth/register, /login, /refresh, GET /me
│   ├── ProviderController.java   # GET /providers/nearby, /search, /{id}
│   │                             # POST/PUT /provider/profile
│   │                             # GET /provider/dashboard
│   ├── ServiceController.java    # CRUD /provider/services
│   ├── BookingController.java    # POST /bookings, GET /bookings/my, /slots
│   ├── ReviewController.java     # POST /reviews, GET /providers/{id}/reviews
│   └── AvailabilityController.java
├── dto/
│   ├── request/                  # Validated inbound payloads
│   └── response/                 # ApiResponse wrappers + DTOs
├── entity/                       # JPA entities
│   ├── User.java
│   ├── ProviderProfile.java
│   ├── Service.java
│   ├── Availability.java
│   ├── Booking.java
│   └── Review.java
├── enums/
│   ├── UserRole.java             # CUSTOMER | PROVIDER | ADMIN
│   ├── Gender.java               # MALE | FEMALE
│   ├── BookingStatus.java        # PENDING | CONFIRMED | CANCELLED | COMPLETED | NO_SHOW
│   └── ServiceCategory.java      # NAILS | HAIR | SPA | MAKEUP | LASHES | SKIN | …
├── exception/
│   ├── GlobalExceptionHandler.java
│   ├── ResourceNotFoundException.java
│   └── BusinessException.java
├── repository/                   # Spring Data repositories + custom JPQL
├── security/
│   ├── JwtUtils.java             # Token generation & validation
│   ├── JwtAuthFilter.java        # OncePerRequestFilter
│   └── UserDetailsServiceImpl.java
└── service/
    ├── AuthService.java  (+ impl)
    ├── ProviderService.java (+ impl) – Haversine geo-search
    ├── ServiceManagementService.java (+ impl)
    ├── BookingService.java (+ impl) – conflict detection + slot generator
    ├── ReviewService.java (+ impl) – rating recalculation
    └── AvailabilityService.java (+ impl)
```

---

## Quick Start

### Prerequisites
- Java 17+
- Maven 3.9+
- Docker & Docker Compose

### 1 – Run locally (recommended, no Docker)

The `local` profile uses an in-memory H2 database, seeds a demo admin and only logs SMS/e-mail/push:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

API available at `http://localhost:8080/api`  
Swagger UI at `http://localhost:8080/api/swagger-ui.html`

`aiwa-backend/docker-compose.yml` only starts PostgreSQL and Redis on 127.0.0.1 for local integration work. It has no
backend service on purpose: the default profile enforces the production settings and refuses to start without them.
Servers use `deploy/docker-compose.prod.yml` (see `docs/release.md`).

### 2 – Run against a real PostgreSQL (needs the production settings, or use the `local` profile above)

```bash
# 1. Start Postgres
docker run -d --name aiwa_pg \
  -e POSTGRES_DB=aiwa_db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 postgres:16-alpine

# 2. Build & run
mvn clean package -DskipTests
java -jar target/aiwa-backend-1.0.0.jar
```

---

## API Endpoints

### Authentication  `/auth`

| Method | Endpoint           | Auth | Description              |
|--------|--------------------|------|--------------------------|
| POST   | `/auth/register`   | ✗    | Register customer/provider |
| POST   | `/auth/login`      | ✗    | Login → JWT tokens        |
| POST   | `/auth/refresh`    | ✗    | Refresh access token      |
| GET    | `/auth/me`         | ✓    | Current user profile      |

### Providers  `/providers` & `/provider`

| Method | Endpoint                      | Auth     | Description                    |
|--------|-------------------------------|----------|--------------------------------|
| GET    | `/providers/nearby`           | ✗        | Geo-search with radius         |
| GET    | `/providers/search?q=`        | ✗        | Search by name                 |
| GET    | `/providers/{id}`             | ✗        | Full profile                   |
| GET    | `/providers/{id}/services`    | ✗        | Provider's services            |
| GET    | `/providers/{id}/availability`| ✗        | Working hours                  |
| GET    | `/providers/{id}/reviews`     | ✗        | Reviews (paginated)            |
| POST   | `/provider/profile`           | PROVIDER | Create profile                 |
| PUT    | `/provider/profile`           | PROVIDER | Update profile                 |
| GET    | `/provider/dashboard`         | PROVIDER | Stats + today's bookings       |

### Services  `/provider/services`

| Method | Endpoint                      | Auth     | Description     |
|--------|-------------------------------|----------|-----------------|
| POST   | `/provider/services`          | PROVIDER | Add service      |
| PUT    | `/provider/services/{id}`     | PROVIDER | Update service   |
| DELETE | `/provider/services/{id}`     | PROVIDER | Soft-delete      |

### Bookings  `/bookings`

| Method | Endpoint                  | Auth     | Description                        |
|--------|---------------------------|----------|------------------------------------|
| POST   | `/bookings`               | CUSTOMER | Create booking                      |
| GET    | `/bookings/{id}`          | ✓        | Get booking                         |
| GET    | `/bookings/my`            | CUSTOMER | My bookings (paginated)             |
| GET    | `/bookings/provider`      | PROVIDER | Provider's bookings                 |
| PATCH  | `/bookings/{id}/status`   | ✓        | Confirm / cancel / complete         |
| GET    | `/bookings/slots`         | ✗        | Available time slots for a day      |

### Reviews  `/reviews`

| Method | Endpoint                      | Auth     | Description                |
|--------|-------------------------------|----------|----------------------------|
| POST   | `/reviews`                    | CUSTOMER | Review a completed booking |

### Availability  `/provider/availability`

| Method | Endpoint                         | Auth     | Description           |
|--------|----------------------------------|----------|-----------------------|
| POST   | `/provider/availability`         | PROVIDER | Set/update day slot   |
| DELETE | `/provider/availability/{id}`    | PROVIDER | Remove day            |

---

## Environment Variables

| Variable          | Default                              | Description            |
|-------------------|--------------------------------------|------------------------|
| `DB_USERNAME`     | `postgres`                           | Database username      |
| `DB_PASSWORD`     | `postgres`                           | Database password      |
| `JWT_SECRET`      | `aiwa-super-secret-key-…`            | **Change in production!** |

---

## Sample Request: Register

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "Layla Hassan",
    "email": "layla@example.com",
    "password": "secret123",
    "role": "CUSTOMER",
    "gender": "FEMALE"
  }'
```

## Sample Request: Nearby Providers

```bash
curl "http://localhost:8080/api/providers/nearby?lat=30.0444&lng=31.2357&radiusKm=5&category=NAILS"
```

## Sample Request: Create Booking

```bash
curl -X POST http://localhost:8080/api/bookings \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "providerId": 1,
    "serviceId": 2,
    "bookingDate": "2026-05-01",
    "startTime": "11:00",
    "notes": "First visit"
  }'
```

---

## Future Enhancements (SRS Phase 2)

- **Online Payments** – Stripe / PayMob integration
- **Push Notifications** – Firebase Cloud Messaging
- **Chat System** – WebSocket with STOMP
- **AI Recommendations** – Provider ranking by user preferences
- **Admin Panel** – User moderation, provider verification
