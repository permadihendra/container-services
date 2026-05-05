# Use official lightweight Python image
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application
COPY app/ .

# Expose port inside container
EXPOSE 5000

# Default command to run
CMD ["python", "main.py"]
