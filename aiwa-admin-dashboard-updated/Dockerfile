# Admin panel image (OPS-8): Vite build, then served by nginx with the CSP in
# deploy/nginx.conf.template. VITE_API_BASE_URL is baked in at build time;
# API_ORIGIN (runtime) feeds the CSP connect-src/img-src.
FROM node:26.10.0-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY . .
ARG VITE_API_BASE_URL
RUN test -n "$VITE_API_BASE_URL" || (echo "Pass --build-arg VITE_API_BASE_URL=https://api.<domain>/api" && exit 1)
# P-05: a release image talks to a real HTTPS API and never ships the mock sign-in. ENV beats any build-arg or .env value.
RUN case "$VITE_API_BASE_URL" in https://*) ;; *) echo "VITE_API_BASE_URL must be an https:// URL (got: $VITE_API_BASE_URL)"; exit 1;; esac
ENV VITE_USE_MOCKS=false
RUN npm test && npm run build

FROM nginxinc/nginx-unprivileged:1.30.5-alpine
COPY deploy/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
ENV API_ORIGIN=""
EXPOSE 8080
