FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir kopf kubernetes

COPY main.py /app/main.py

CMD ["kopf", "run", "--standalone", "--namespace=homework", "/app/main.py"]
