# Define AWS provider and set the region for resource provisioning
provider "aws" {
  region = "us-east-1"
}

# Create a Virtual Private Cloud to isolate the infrastructure
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Django_EC2_VPC"
  }
}

# Internet Gateway to allow internet access to the VPC
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags = {
    Name = "Django_EC2_Internet_Gateway"
  }
}

# Route table for controlling traffic leaving the VPC
resource "aws_route_table" "default" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
  tags = {
    Name = "Django_EC2_Route_Table"
  }
}

# Subnet within VPC for resource allocation, in availability zone us-east-1a
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "Django_EC2_Subnet_1"
  }
}

# Another subnet for redundancy, in availability zone us-east-1b
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
  tags = {
    Name = "Django_EC2_Subnet_2"
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.default.id
}

# Associate private subnet with private route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.default.id
}

# Security group for EC2 instance
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.default.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "EC2_Security_Group"
  }
}

# Define variable for Django secret key to avoid hardcoding secrets
variable "secret_key" {
  description = "The Secret Key for Django"
  type        = string
  sensitive   = true
}

# EC2 instance for the local web app
resource "aws_instance" "web" {
    ami                    = "ami-0c101f26f147fa7fd" # Amazon Linux
  instance_type          = "t3.micro"
  key_name               = "my-key-pair"
  subnet_id              = aws_subnet.subnet1.id # Place this instance in the public subnet
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  associate_public_ip_address = true # Assigns a public IP address to your instance
  user_data_replace_on_change = true # Replace the user data when it changes

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx docker aws-cli
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    # Configure nginx with fallback
    echo 'OK' > /usr/share/nginx/html/health
    echo '<h1>Django Loading...</h1>' > /usr/share/nginx/html/index.html
    cat > /etc/nginx/conf.d/django.conf << 'NGINX_EOF'
server {
    listen 80 default_server;
    location /health { root /usr/share/nginx/html; }
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_connect_timeout 1s;
        error_page 502 503 504 /index.html;
    }
}
NGINX_EOF
    rm -f /etc/nginx/sites-enabled/default
    systemctl start nginx
    systemctl enable nginx
    
    # Try Django container
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 766158721264.dkr.ecr.us-east-1.amazonaws.com
    docker run -d --name django-app -p 8000:8080 \
      -e SECRET_KEY="${var.secret_key}" \
      -e ALLOWED_HOSTS="*" \
      766158721264.dkr.ecr.us-east-1.amazonaws.com/django-ec2-complete:latest
    EOF

  tags = {
    Name = "Django_EC2_Complete_Server"
  }
}

# IAM role for EC2 instance to access ECR
resource "aws_iam_role" "ec2_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ec2.amazonaws.com",
      },
      Effect = "Allow",
    }],
  })
}

# Attach the AmazonEC2ContainerRegistryReadOnly policy to the role
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# IAM instance profile for EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}


