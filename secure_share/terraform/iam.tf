resource "aws_iam_user" "app_user" {
  name = "django-app-user"
}

resource "aws_iam_access_key" "app_user_key" {
  user = aws_iam_user.app_user.name
}

resource "aws_iam_user_policy" "app_policy" {
  name = "s3-access"
  user = aws_iam_user.app_user.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}