# syntax=docker/dockerfile:1

# ---- build stage: compile the React app into static files ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build          # outputs static assets to /app/dist

# ---- runtime stage: serve the static files with nginx ----
FROM nginx:1.27-alpine AS runtime
# Replace the default site with ours (adds the /api proxy + SPA fallback).
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
