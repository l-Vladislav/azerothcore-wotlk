# Фронтенд собирается здесь же, а не руками на машине владельца: иначе в образ
# уезжает то, что в последний раз оказалось в dist, и понять, из какого кода оно
# собрано, нельзя.
FROM node:22-alpine AS web

WORKDIR /web
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
# Новый фронт живёт под /ui/, старые страницы остаются на своих адресах.
RUN npm run build -- --base-href=/ui/

FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
COPY --from=web /web/dist/admin-panel-web/browser ./web/

EXPOSE 8091
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8091"]
