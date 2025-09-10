# DB subnet group for RDS instances, using the created subnets
resource "aws_db_subnet_group" "default" {
  subnet_ids  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  tags = {
    Name = "Django_EC2_Subnet_Group"
  }
}

# Security group for rds, allows PostgreSQL traffic
resource "aws_security_group" "rds" {
  name        = "RDS_Security_Group"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.default.id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "RDS_Security_Group"
  }
}

variable "db_password" {
  type        = string
  description = "Password for the database"
  sensitive   = true
}

# RDS instance for Django backend, now privately accessile
resource "aws_db_instance" "default" {
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "postgres"
  engine_version          = "17.5"
  instance_class          = "db.t3.micro"
  db_name                 = "mydjangords"
  username                = "novey"
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.default.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  publicly_accessible     = true
  multi_az                = false
  tags = {
    Name = "Django_RDS_Instance"
  }
}

