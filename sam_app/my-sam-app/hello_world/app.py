def lambda_handler(event, context):
    html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>Novey Cloud</title>
</head>
<body>
    <h1>Welcome to Django!</h1>
    <p>This is your index.html page.</p>
</body>
</html>
    """
    
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/html"
        },
        "body": html_content
    }