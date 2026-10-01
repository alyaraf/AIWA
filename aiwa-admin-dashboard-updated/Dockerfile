# Admin panel image (OPS-8): Vite build, then served by nginx with the CSP in
# deploy/nginx.conf.template. VITE_API_BASE_URL is baked in at build time;
# API_ORIGIN (runtime) feeds the CSP connect-src/img-src.
FROM node:20.20.2-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG VITE_API_BASE_URL
RUN test -n "$VITE_API_BASE_URL" || (echo "Pass --build-arg VITE_API_BASE_URL=https://api.<domain>/api" && exit 1)
RUN npm test && npm run build

FROM nginxinc/nginx-unprivileged:1.30.5-alpine
COPY deploy/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
ENV API_ORIGIN=""
EXPOSE 8080
