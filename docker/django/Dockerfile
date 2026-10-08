FROM python:3.13
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
ENV POSTGRES_HOST=${DB_HOST}
ENV POSTGRES_PORT=${DB_PORT}
ENV POSTGRES_NAME=${DB_NAME}
ENV POSTGRES_USER=${DB_USER}
ENV POSTGRES_PASSWORD=${DB_PASSWORD}
COPY . .
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]