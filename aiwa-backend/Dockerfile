# ── Build stage ───────────────────────────────────────────────
# Exact versions (R2-20): a rebuild produces the same image, not whatever "17" means today.
FROM maven:3.9.16-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q clean package -DskipTests

# ── Runtime stage ─────────────────────────────────────────────
FROM eclipse-temurin:17.0.20.1_1-jre-alpine
WORKDIR /app

# Run as an unprivileged user; uploads live on a mounted volume it owns.
RUN addgroup -S aiwa && adduser -S aiwa -G aiwa \
    && mkdir -p /app/uploads/public /app/uploads/private \
    && chown -R aiwa:aiwa /app
COPY --from=build --chown=aiwa:aiwa /app/target/*.jar app.jar
USER aiwa

ENV TZ=Africa/Cairo \
    STORAGE_PUBLIC_PATH=/app/uploads/public \
    STORAGE_PRIVATE_PATH=/app/uploads/private \
    JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/api/actuator/health/liveness | grep -q UP || exit 1
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
