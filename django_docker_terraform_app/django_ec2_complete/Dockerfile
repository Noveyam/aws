FROM python:3.13.0
ENV PYTHONBUFFERED=1
ENV PORT 8080
WORKDIR /app
COPY . /app/
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

CMD gunicorn django_ec2_complete.wsgi:application --bind 0.0.0.0:$PORT

EXPOSE ${PORT}