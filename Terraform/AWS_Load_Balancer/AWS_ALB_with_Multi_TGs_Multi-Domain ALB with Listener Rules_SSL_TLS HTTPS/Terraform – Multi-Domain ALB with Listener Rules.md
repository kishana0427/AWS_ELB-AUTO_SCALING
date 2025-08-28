🏗 Terraform – Multi-Domain ALB with Listener Rules
main.tf (new/extended parts)


#################################
# ACM Certificates for Both Domains
#################################

resource "aws_acm_certificate" "multi_cert" {
  domain_name       = "example.com"
  subject_alternative_names = [
    "app.example.com",
    "api.example.com"
  ]
  validation_method = "DNS"
}

# DNS Validation Records (for each domain)
resource "aws_route53_record" "cert_validation_app" {
  name    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_type
  zone_id = "ZXXXXXXXXXXXX" # Replace with your Route53 Hosted Zone ID
  records = [tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_route53_record" "cert_validation_api" {
  name    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_name
  type    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_type
  zone_id = "ZXXXXXXXXXXXX"
  records = [tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "multi_cert_validation" {
  certificate_arn         = aws_acm_certificate.multi_cert.arn
  validation_record_fqdns = [
    aws_route53_record.cert_validation_app.fqdn,
    aws_route53_record.cert_validation_api.fqdn
  ]
}

#################################
# Target Groups
#################################

# App Service TG
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# API Service TG
resource "aws_lb_target_group" "api_tg" {
  name     = "api-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# (You can attach EC2/ECS/EKS services to each TG)
# Example EC2 for API
resource "aws_instance" "api" {
  ami           = "ami-0cda377a1b884a1bc"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              echo "<h1>Hello from API Service</h1>" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
              EOF
}

resource "aws_lb_target_group_attachment" "api_attach" {
  target_group_arn = aws_lb_target_group.api_tg.arn
  target_id        = aws_instance.api.id
  port             = 80
}

#################################
# HTTPS Listener with Rules
#################################

resource "aws_lb_listener" "https_multi" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.multi_cert_validation.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Rule for app.example.com
resource "aws_lb_listener_rule" "app_rule" {
  listener_arn = aws_lb_listener.https_multi.arn
  priority     = 1

  condition {
    host_header {
      values = ["app.example.com"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Rule for api.example.com
resource "aws_lb_listener_rule" "api_rule" {
  listener_arn = aws_lb_listener.https_multi.arn
  priority     = 2

  condition {
    host_header {
      values = ["api.example.com"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

#################################
# Route53 Records
#################################

resource "aws_route53_record" "app_record" {
  zone_id = "ZXXXXXXXXXXXX"
  name    = "app.example.com"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_record" {
  zone_id = "ZXXXXXXXXXXXX"
  name    = "api.example.com"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}


✅ What This Does

Requests ACM certificate for both app.example.com and api.example.com

Creates two Target Groups (app-tg, api-tg)

Configures HTTPS listener (443) on ALB

Adds listener rules to forward based on hostname:

app.example.com → App TG

api.example.com → API TG

Route53 records map both domains to ALB

🌍 Result

Visit https://app.example.com