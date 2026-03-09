FROM python:3.12-slim

WORKDIR /app

COPY services/log-relay/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/log-relay/main.py .

EXPOSE 8080

CMD ["python", "main.py"]
