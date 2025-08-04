# Use a lightweight Python image
FROM python:3.11-slim

# Disable bytecode and enable live output
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the Django project files
COPY . .

# Run the Django app with Gunicorn
CMD ["gunicorn", "secure_share.wsgi:application", "--bind", "0.0.0.0:8000"]