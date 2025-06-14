FROM python:3.11-slim

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Create directory for database
RUN mkdir -p /app/data

# Set environment variable for database location
ENV DATABASE_PATH=/app/data/consent_store.db

EXPOSE 8001

CMD ["uvicorn", "consent_store:app", "--host", "0.0.0.0", "--port", "8001"]