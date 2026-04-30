FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    sqlite3 \
    git \
    tzdata \
    bash \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app.py .
COPY zap2xml.py .
COPY run-multi.sh .
COPY scheduler.sh .
COPY start.sh .

# Copy templates directory
COPY templates/ /app/templates/

# Create necessary directories
RUN mkdir -p /app/templates && \
    mkdir -p /config && \
    mkdir -p /output/logs && \
    mkdir -p /data

# Convert line endings and set permissions
RUN dos2unix /app/*.sh 2>/dev/null || true && \
    chmod +x /app/run-multi.sh && \
    chmod +x /app/scheduler.sh && \
    chmod +x /app/start.sh && \
    chmod +x /app/zap2xml.py

EXPOSE 5000 8282

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1

CMD ["/app/start.sh"]