# files/views.py
import boto3
from django.conf import settings
from django.shortcuts import get_object_or_404
from .models import SharedFile

def generate_presigned_url(file_key, expiration=3600):
    s3_client = boto3.client('s3',
        region_name=settings.AWS_S3_REGION_NAME,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )
    return s3_client.generate_presigned_url(
        'get_object',
        Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': file_key},
        ExpiresIn=expiration
    )