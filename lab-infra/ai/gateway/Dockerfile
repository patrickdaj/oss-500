# AI gateway image (ai-access / ai-guardrails). Built + kind-loaded by ../up.sh.
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
# Non-root (restricted-PSA compliant).
RUN useradd -u 10001 -m gateway
USER 10001
EXPOSE 8080
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
