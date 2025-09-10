# Reference existing ACM certificate
data "aws_acm_certificate" "cert" {
  domain   = "noveycloud.com"
  statuses = ["ISSUED"]
}

# Declare the Route 53 zone for the domain
data "aws_route53_zone" "selected" {
  name = "noveycloud.com"
}

# Certificate validation records already exist - commented out to avoid conflicts
# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }
#
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.selected.zone_id
# }

# Route53 records already exist - managed outside Terraform

# Certificate validation resource commented out since validation records already exist
# resource "aws_acm_certificate_validation" "cert" {
#   provider                = aws
#   certificate_arn         = aws_acm_certificate.cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }

# Security group for ALB, allows HTTPS traffic
resource "aws_security_group" "alb_sg" {
  name        = "alb-https-security-group"
  description = "Allow all inbound HTTPS traffic"
  vpc_id      = aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer for HTTPS traffic
resource "aws_lb" "default" {
  name               = "django-ec2-alb-https"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false
}

# Target group for the ALB to route traffic from ALB to VPC
resource "aws_lb_target_group" "default" {
  name        = "django-ec2-alb-tg-http"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.default.id
  
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
    protocol            = "HTTP"
    port                = "traffic-port"
  }
}

# Attach the EC2 instance to the target group
resource "aws_lb_target_group_attachment" "default" {
  target_group_arn = aws_lb_target_group.default.arn
  target_id        = aws_instance.web.id # Your EC2 instance ID
  port             = 80 # Port the EC2 instance listens on; adjust if different
}

# HTTP listener for the ALB to redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.default.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener for the ALB to route traffic to the target group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.default.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

/*
for terraform errors on arm

export TFENV_ARCH=arm64
export GODEBUG=asyncpreemptoff=1

*/