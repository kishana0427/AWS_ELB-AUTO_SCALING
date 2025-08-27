provider "aws" {
  region = "ap-south-1" # change to your preferred region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id
  name   = "web-sg"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
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



resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  name   = "alb-sg"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "Allow HTTPS"
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


# Launch EC2 Instances (Sample Web App)
resource "aws_instance" "web_a" {
  ami           = "ami-0861f4e788f5069dd" # Amazon Linux 2 AMI (check latest)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_a.id
  key_name      = "mrcet-key"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              echo "<h1>Hello from Web A</h1>" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
              EOF
}

resource "aws_instance" "web_b" {
  ami           = "ami-0861f4e788f5069dd"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_b.id
  key_name      = "mrcet-key"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              echo "<h1>Hello from Web B</h1>" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
              EOF
}

# ALB
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Attach Instances to Target Group
resource "aws_lb_target_group_attachment" "web_a" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_b" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web_b.id
  port             = 80
}

# Listener
# REMOVE this block
#resource "aws_lb_listener" "http" {
#  load_balancer_arn = aws_lb.app_lb.arn
#  port              = "80"
#  protocol          = "HTTP"

#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_tg.arn
#  }
#}

# Route53 DNS record (optional - replace with your hosted zone ID & domain)
#resource "aws_route53_record" "app_record" {
#  zone_id = "ZXXXXXXXXXXXX" # Replace with your hosted zone ID
#  name    = "app.example.com"
#  type    = "A"

#  alias {
#    name                   = aws_lb.app_lb.dns_name
#    zone_id                = aws_lb.app_lb.zone_id
#    evaluate_target_health = true
#  }
#}



# Request ACM Certificate for your domain
resource "aws_acm_certificate" "app_cert" {
  domain_name       = "krish.kozow.com"     # Replace with your domain
  validation_method = "DNS"
}


# Validate certificate
resource "aws_acm_certificate_validation" "app_cert_validation" {
  certificate_arn         = aws_acm_certificate.app_cert.arn
#  validation_record_fqdns = [krish.kozow.com]
}

# HTTPS Listener (443) with ACM Certificate
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.app_cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Redirect HTTP → HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
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


#       NOTE:
#       ====
#  1.Manually add DNS Record of type CNAME from ACM Certificates
#    like CNAME name(_1e1c759ba9fa768a8f6441a071a119ba.krish.kozow.com.) and
#    CNAME value(_4f252fed6e508d9d4d4a3d5408de4f1e.xlfgrmvvlj.acm-validations.aws.) to dynu.com(out side Route53)

#  2.Add load_balancer_dns dns name to dynu.com DNS Record of type CNAME and apply terraform again
