FROM node:18-bullseye AS frontend-build
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
COPY frontend/next.config.js ./
COPY frontend/public ./public
COPY frontend/pages ./pages
COPY frontend/styles ./styles
RUN npm ci
RUN npm run build

FROM python:3.11-slim AS runtime
WORKDIR /app
ENV PORT=8080
EXPOSE 8080
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend ./backend
COPY --from=frontend-build /app/frontend/out ./static
CMD ["gunicorn", "-b", "0.0.0.0:8080", "backend.app:app"]
