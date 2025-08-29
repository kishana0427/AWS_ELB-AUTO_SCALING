want to create an AWS Load Balancer with Terraform, attach a sample web application (like NGINX), configure a target group, and associate a domain name to the Load Balancer.

Here’s a production-style but minimal example with Terraform:

Directory Structure

alb-terraform/
 ├─ main.tf
 ├─ variables.tf
 ├─ outputs.tf

main.tf

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch EC2 Instances (Sample Web App)
resource "aws_instance" "web_a" {
  ami           = "ami-0cda377a1b884a1bc" # Amazon Linux 2 AMI (check latest)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_a.id
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
  ami           = "ami-0cda377a1b884a1bc"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_b.id
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
  security_groups    = [aws_security_group.web_sg.id]
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
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Route53 DNS record (optional - replace with your hosted zone ID & domain)
resource "aws_route53_record" "app_record" {
  zone_id = "ZXXXXXXXXXXXX" # Replace with your hosted zone ID
  name    = "app.example.com"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}


variables.tf

variable "region" {
  default = "ap-south-1"
}


outputs.tf

output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}


🚀 Steps to Deploy

Save files in a directory (alb-terraform/).

Run:

terraform init
terraform apply -auto-approve

Get the ALB DNS:

terraform output load_balancer_dns


Open in browser → you should see load balanced responses:

Hello from Web A

Hello from Web B

(Optional) If you configured Route53, your domain (app.example.com) will resolve to the ALB.

👉 you want me to also extend this with SSL/TLS (HTTPS) using ACM and ALB listener rules?


Let’s extend the setup to include SSL/TLS (HTTPS) with ACM certificate + ALB listener rules.

This way your domain (app.example.com) will be accessible via HTTPS (443) with a valid certificate.

🔐 Updated Terraform with HTTPS

We’ll add:

ACM Certificate for your domain

HTTPS Listener on ALB (port 443)

Forward traffic to Target Group

main.tf (extended parts only)

# Request ACM Certificate for your domain
resource "aws_acm_certificate" "app_cert" {
  domain_name       = "app.example.com"     # Replace with your domain
  validation_method = "DNS"
}

# Create DNS record for certificate validation
resource "aws_route53_record" "cert_validation" {
  name    = tolist(aws_acm_certificate.app_cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.app_cert.domain_validation_options)[0].resource_record_type
  zone_id = "ZXXXXXXXXXXXX"  # Replace with your Route53 Hosted Zone ID
  records = [tolist(aws_acm_certificate.app_cert.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

# Validate certificate
resource "aws_acm_certificate_validation" "app_cert_validation" {
  certificate_arn         = aws_acm_certificate.app_cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
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


outputs.tf (extended)


output "https_domain" {
  value = "https://app.example.com"
}

output "https_alb_dns" {
  value = aws_lb.app_lb.dns_name
}


🔑 Deployment Steps

Update your domain in Route53:

Add an A record alias (app.example.com) pointing to ALB.
(Already done in previous config)

Apply Terraform:

terraform init
terraform apply -auto-approve


Wait for ACM validation:

AWS will check the Route53 validation record automatically.

Once validated → Certificate becomes Issued.

Access:

http://app.example.com → will redirect to HTTPS

https://app.example.com → secured by ACM SSL

✅ Now you have:

Load Balancer (ALB) across multiple AZs

EC2 Web App behind Target Group

Domain via Route53

HTTPS with ACM certificate

Auto redirect from HTTP → HTTPS

👉 Do you also want me to add multiple domains/subdomains on the same ALB with listener rules (e.g., api.example.com → service A, app.example.com → service B)?


👍 Let’s extend this into a multi-domain / multi-service ALB setup using listener rules.

This will let you host multiple services behind the same ALB — for example:

app.example.com → forwards to App target group

api.example.com → forwards to API target group

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


🚀 Let’s take this one step further:

We’ll build a production-ready ALB with multiple domains that routes to microservices running on Amazon EKS (instead of EC2).

🏗️ Architecture

Amazon EKS Cluster hosts microservices (e.g., app-service, api-service).

AWS Load Balancer Controller manages an ALB automatically.

ACM SSL Certificate provides HTTPS.

Ingress resources define hostname-based routing:

app.example.com → forwards to app-service (Pods).

api.example.com → forwards to api-service.

🔑 Terraform Setup

We’ll split into 2 parts:

EKS Cluster + Node Group (Terraform)

Ingress + Services + ACM Cert (YAML Helm manifests applied via Terraform)

1️⃣ EKS Cluster + ALB Controller (Terraform)


provider "aws" {
  region = "ap-south-1"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "microservices-cluster"
  cluster_version = "1.29"
  subnets         = ["subnet-xxxx", "subnet-yyyy"] # your public/private subnets
  vpc_id          = "vpc-xxxxxx"

  node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
      instance_types   = ["t3.medium"]
    }
  }
}

# Install AWS Load Balancer Controller (via Helm)
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = "ap-south-1"
  }

  set {
    name  = "vpcId"
    value = "vpc-xxxxxx"
  }
}



2️⃣ Microservices Deployment + Ingress (YAML via Terraform)

Ingress with host-based routing + SSL (using ACM cert ARN).


resource "kubernetes_namespace" "microservices" {
  metadata {
    name = "microservices"
  }
}

# Sample App Service
resource "kubernetes_deployment" "app" {
  metadata {
    name      = "app-deployment"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }

  spec {
    replicas = 2
    selector {
      match_labels = { app = "app-service" }
    }
    template {
      metadata {
        labels = { app = "app-service" }
      }
      spec {
        container {
          name  = "app-container"
          image = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "app-service"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }
  spec {
    selector = { app = "app-service" }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

# Sample API Service
resource "kubernetes_deployment" "api" {
  metadata {
    name      = "api-deployment"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }

  spec {
    replicas = 2
    selector {
      match_labels = { app = "api-service" }
    }
    template {
      metadata {
        labels = { app = "api-service" }
      }
      spec {
        container {
          name  = "api-container"
          image = "httpd"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "api" {
  metadata {
    name      = "api-service"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }
  spec {
    selector = { app = "api-service" }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

# Ingress with host rules
resource "kubernetes_ingress" "micro_ingress" {
  metadata {
    name      = "micro-ingress"
    namespace = kubernetes_namespace.microservices.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/scheme"                  = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"             = "ip"
      "alb.ingress.kubernetes.io/certificate-arn"         = "arn:aws:acm:ap-south-1:111111111111:certificate/xxxxxxx"
      "alb.ingress.kubernetes.io/listen-ports"            = `[{"HTTP":80,"HTTPS":443}]`
      "alb.ingress.kubernetes.io/ssl-redirect"            = "443"
    }
  }

  spec {
    rule {
      host = "app.example.com"
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = "api.example.com"
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.api.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}



🌍 How It Works

ALB Controller provisions an ALB in your VPC.

ALB uses ACM certificate for HTTPS (443).

Ingress rules map hostnames:

app.example.com → forwards to app-service Pods.

api.example.com → forwards to api-service Pods.

Route53 A records (not shown, same as before) point each domain → ALB DNS.

✅ Result

https://app.example.com → NGINX Pods (App Service)

https://api.example.com → Apache Pods (API Service)

ALB terminates SSL, handles routing, scales with Kubernetes

👉 Do you want me to wrap this whole thing into a Terraform + Helm starter kit for multi-domain EKS microservices (so you can just terraform apply and get everything ready)?



# Terraform + Helm Starter Kit — EKS + ALB + Multi-domain Ingress

**What this kit contains**
A production-ready starter kit to create an Amazon EKS cluster with an ALB (via AWS Load Balancer Controller), ACM-managed SSL certificates, Route53 DNS records, and Helm/Kubernetes manifests to deploy two microservices (`app` and `api`) with hostname-based routing for `app.example.com` and `api.example.com`.

---

## Directory structure

```
eks-alb-starter/
├── README.md
├── terraform/
│   ├── backend.tf
│   ├── providers.tf
│   ├── vpc.tf
│   ├── eks-cluster.tf
│   ├── alb-controller.tf
│   ├── route53-acm.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
└── k8s/
    ├── helm-values/
    │   ├── app/values.yaml
    │   └── api/values.yaml
    ├── charts/
    │   ├── app/Chart.yaml
    │   └── api/Chart.yaml
    └── ingress/ingress.yaml
```

---

## High-level overview

* `terraform/` provisions VPC, EKS cluster (using the official terraform-aws-modules/eks), installs the AWS Load Balancer Controller via Helm, provisions ACM certificate and Route53 records, and outputs the ALB DNS and ACM ARN.
* `k8s/` contains simple Helm chart scaffolds and an Ingress manifest (host-based routing) that uses the aws-load-balancer-controller annotations to request an ALB and attach the ACM cert.

---

## Key files (already included below)

### `terraform/providers.tf`

```hcl
provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
```

---

### `terraform/eks-cluster.tf`

```hcl
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = var.k8s_version
  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets

  node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
      instance_types   = ["t3.medium"]
    }
  }
}

# obtain auth token
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
```

---

### `terraform/alb-controller.tf`

```hcl
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_id
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
}
```

---

### `terraform/route53-acm.tf`

```hcl
resource "aws_acm_certificate" "multi_cert" {
  domain_name               = var.root_domain
  subject_alternative_names = var.san_domains
  validation_method         = "DNS"
}

# Create validation records for each option
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.multi_cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "multi_cert_validation" {
  certificate_arn = aws_acm_certificate.multi_cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
```

---

### `terraform/route53-records.tf`

```hcl
resource "aws_route53_record" "app" {
  zone_id = var.route53_zone_id
  name    = "app.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = var.route53_zone_id
  name    = "api.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}
```

---

### `k8s/ingress/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: micro-ingress
  namespace: microservices
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: "${ACM_CERT_ARN}"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80,"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
    - host: app.${ROOT_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
    - host: api.${ROOT_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
```

---

### `k8s/helm-values/app/values.yaml`

```yaml
replicaCount: 2
image:
  repository: nginx
  tag: "stable"
service:
  type: ClusterIP
  port: 80
```

### `k8s/helm-values/api/values.yaml`

```yaml
replicaCount: 2
image:
  repository: httpd
  tag: latest
service:
  type: ClusterIP
  port: 80
```

---

## README (usage summary)

1. Edit `terraform/variables.tf` and set:

   * `region`, `cluster_name`, `route53_zone_id`, `root_domain`, `san_domains` etc.
2. Configure remote state in `backend.tf` (optional but recommended for prod).
3. Initialize and apply Terraform:

   ```bash
   cd terraform
   terraform init
   terraform apply -auto-approve
   ```
4. After EKS + ALB controller is ready, update `k8s/ingress/ingress.yaml`:

   * Replace `${ACM_CERT_ARN}` and `${ROOT_DOMAIN}` with outputs from Terraform or use Helm templating.
5. Deploy microservices via Helm or `kubectl apply`:

   ```bash
   # example with kubectl and KUBECONFIG from terraform outputs
   kubectl create namespace microservices
   kubectl apply -f k8s/ingress/ingress.yaml

   # or use Helm charts under k8s/charts/
   helm install app k8s/charts/app -n microservices -f k8s/helm-values/app/values.yaml
   helm install api k8s/charts/api -n microservices -f k8s/helm-values/api/values.yaml
   ```
6. Create Route53 A alias records (Terraform will do this if configured).

---

## Notes & Recommendations

* Use `target-type: ip` for ALB Ingress so pods (via ENI) can be targetted directly. If using `NodePort`/`instance` change accordingly.
* For production, consider private subnets for worker nodes and a public ALB.
* Enable autoscaling (Cluster Autoscaler + HPA) for resilience.
* Secure your Terraform state (S3 + DynamoDB lock).

---

If you want, I can now:

* generate these files and present them individually for download, or
* produce a single zip file you can download, or
* convert the ingress manifest to Helm templates with values that pull ACM ARN from Terraform outputs.

Tell me which of the above you'd like next.


Done — I created the Terraform + Helm starter kit in the canvas (file titled Terraform-eks-alb-helm-starter-kit).

Open the canvas on the right to view the full project (files, Terraform, Helm values, and README).

Next options — pick one and I’ll do it now:

Generate a downloadable ZIP of the entire project.

Convert the ingress.yaml to a Helm chart with templated values and hook it into Terraform outputs.

Provide a step-by-step deploy checklist tailored to your AWS account (includes exact terraform apply command, kubectl commands, and what to watch in the AWS Console).

Which do you want?



give me vpc.tf outputs.tf variables.tf versions.tf for eks version1.33


Here are the four Terraform files you requested for EKS v1.33 setup.


versions.tf

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}


variables.tf


variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnets CIDR"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnets CIDR"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-cluster"
}

variable "eks_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.33"
}


vpc.tf



provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.eks_cluster_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.eks_cluster_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                        = "${var.eks_cluster_name}-public-${count.index}"
    "kubernetes.io/role/elb"    = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnets[count.index]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                 = "${var.eks_cluster_name}-private-${count.index}"
    "kubernetes.io/role/internal-elb"    = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

data "aws_availability_zones" "available" {}



outputs.tf


output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "Public Subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "Private Subnet IDs"
  value       = aws_subnet.private[*].id
}

output "region" {
  description = "AWS region"
  value       = var.region
}


✅ This gives you a VPC with public + private subnets, ready for an EKS v1.33 cluster.

Do you want me to also prepare eks.tf and nodegroup.tf so that you have a complete EKS cluster setup (with worker nodes) on top of this VPC?



👍 — here’s a backend.tf you can drop into your project so Terraform state is stored remotely in S3 with DynamoDB lock (production-ready).


terraform {
  backend "s3" {
    bucket         = "my-eks-terraform-state"   # <-- change this to your S3 bucket name
    key            = "eks-cluster/terraform.tfstate"
    region         = "ap-south-1"               # <-- change region if needed
    dynamodb_table = "terraform-locks"          # <-- change this to your DynamoDB table name
    encrypt        = true
  }
}


⚡ Setup Notes

Create an S3 bucket (must exist before running terraform init):


aws s3api create-bucket --bucket my-eks-terraform-state --region ap-south-1


Create a DynamoDB table for state locking:


aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region ap-south-1


Then run:

terraform init


👉 Do you want me to also add the IAM policy JSON that your Terraform user needs for managing the S3 backend + DynamoDB locking? That way you can assign it directly.



yaml for below code:
===================

resource "kubernetes_namespace" "microservices" {
  metadata {
    name = "microservices"
  }
}

# Sample App Service
resource "kubernetes_deployment" "app" {
  metadata {
    name      = "app-deployment"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }

  spec {
    replicas = 2
    selector {
      match_labels = { app = "app-service" }
    }
    template {
      metadata {
        labels = { app = "app-service" }
      }
      spec {
        container {
          name  = "app-container"
          image = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "app-service"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }
  spec {
    selector = { app = "app-service" }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

# Sample API Service
resource "kubernetes_deployment" "api" {
  metadata {
    name      = "api-deployment"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }

  spec {
    replicas = 2
    selector {
      match_labels = { app = "api-service" }
    }
    template {
      metadata {
        labels = { app = "api-service" }
      }
      spec {
        container {
          name  = "api-container"
          image = "httpd"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "api" {
  metadata {
    name      = "api-service"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }
  spec {
    selector = { app = "api-service" }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

# Ingress with host rules
resource "kubernetes_ingress" "micro_ingress" {
  metadata {
    name      = "micro-ingress"
    namespace = kubernetes_namespace.microservices.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/scheme"                  = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"             = "ip"
      "alb.ingress.kubernetes.io/certificate-arn"         = "arn:aws:acm:ap-south-1:111111111111:certificate/xxxxxxx"
      "alb.ingress.kubernetes.io/listen-ports"            = `[{"HTTP":80,"HTTPS":443}]`
      "alb.ingress.kubernetes.io/ssl-redirect"            = "443"
    }
  }

  spec {
    rule {
      host = "app.example.com"
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = "api.example.com"
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.api.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}


==================================>>>>
Here’s the equivalent YAML manifests for your Terraform resources:

---
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-service
  template:
    metadata:
      labels:
        app: app-service
    spec:
      containers:
        - name: app-container
          image: nginx
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: microservices
spec:
  selector:
    app: app-service
  ports:
    - port: 80
      targetPort: 80
  type: NodePort
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
    spec:
      containers:
        - name: api-container
          image: httpd
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: microservices
spec:
  selector:
    app: api-service
  ports:
    - port: 80
      targetPort: 80
  type: NodePort
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: micro-ingress
  namespace: microservices
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:111111111111:certificate/xxxxxxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80,"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80

✅ This YAML does exactly what your Terraform config describes:

Creates the microservices namespace

Deploys nginx (app-service) and httpd (api-service)

Exposes them via NodePort

Configures an Ingress with AWS ALB annotations and two host rules:

app.example.com → app-service

api.example.com → api-service

Do you want me to also add Horizontal Pod Autoscaler (HPA) YAML for both services so it’s closer to production-ready?



charts for app and api


👍
You want Helm charts for both app and api microservices (with Nginx and Apache Httpd respectively) so you can deploy them instead of writing raw YAML every time.

Here’s a clean Helm chart structure for each service.

📂 Chart: app

# Chart.yaml
apiVersion: v2
name: app
description: A Helm chart for Nginx App service
type: application
version: 0.1.0
appVersion: "1.0"

# values.yaml
replicaCount: 2

image:
  repository: nginx
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: NodePort
  port: 80

resources: {}

# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}-deployment
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}-container
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80


# templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}-service
  namespace: {{ .Release.Namespace }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Chart.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80



📂 Chart: api

# Chart.yaml
apiVersion: v2
name: api
description: A Helm chart for Httpd API service
type: application
version: 0.1.0
appVersion: "1.0"


# values.yaml
replicaCount: 2

image:
  repository: httpd
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: NodePort
  port: 80

resources: {}


# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}-deployment
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}-container
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80

# templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}-service
  namespace: {{ .Release.Namespace }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Chart.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80

✅ With these charts:

Run helm install app ./app --namespace microservices

Run helm install api ./api --namespace microservices

They will deploy your Nginx-based App and Httpd-based API with their own Deployments and Services.

Would you also like me to create a separate Helm chart for the Ingress (so it manages routing for both app.example.com and api.example.com) or should I merge ingress into one of the charts?

👍 you want the full Helm chart folder structure so you can helm create-style deploy without confusion.
Here’s how your two charts (app and api) should look:

📂 app/ Helm Chart (Nginx)

app/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── _helpers.tpl

app/Chart.yaml

apiVersion: v2
name: app
description: A Helm chart for Nginx App service
type: application
version: 0.1.0
appVersion: "1.0"

app/values.yaml

replicaCount: 2

image:
  repository: nginx
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: NodePort
  port: 80

resources: {}


app/templates/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "app.fullname" . }}-deployment
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "app.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "app.name" . }}
    spec:
      containers:
        - name: {{ .Chart.Name }}-container
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80


app/templates/service.yaml


apiVersion: v1
kind: Service
metadata:
  name: {{ include "app.fullname" . }}-service
  namespace: {{ .Release.Namespace }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ include "app.name" . }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80


app/templates/_helpers.tpl

{{- define "app.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "app.fullname" -}}
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}


📂 api/ Helm Chart (Apache Httpd)

api/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── _helpers.tpl


api/Chart.yaml

apiVersion: v2
name: api
description: A Helm chart for Httpd API service
type: application
version: 0.1.0
appVersion: "1.0"


api/values.yaml

replicaCount: 2

image:
  repository: httpd
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: NodePort
  port: 80

resources: {}


api/templates/deployment.yaml


apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "api.fullname" . }}-deployment
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "api.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "api.name" . }}
    spec:
      containers:
        - name: {{ .Chart.Name }}-container
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80

api/templates/service.yaml

apiVersion: v1
kind: Service
metadata:
  name: {{ include "api.fullname" . }}-service
  namespace: {{ .Release.Namespace }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ include "api.name" . }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80

api/templates/_helpers.tpl

{{- define "api.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "api.fullname" -}}
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}


✅ Now you have two independent Helm charts (app and api) with full template paths.
Run like this:

helm install app ./app --namespace microservices --create-namespace
helm install api ./api --namespace microservices


👉 Do you also want me to create a shared ingress chart that routes

app.example.com → app-service

api.example.com → api-service
so your ALB can handle domain-based routing?

add template for deployment and service path for below structure: eks-alb-starter/ ├── README.md ├── terraform/ │ ├── backend.tf │ ├── providers.tf │ ├── vpc.tf │ ├── eks-cluster.tf │ ├── alb-controller.tf │ ├── route53-acm.tf │ ├── outputs.tf │ ├── variables.tf │ └── versions.tf └── k8s/ ├── helm-values/ │ ├── app/values.yaml │ └── api/values.yaml ├── charts/ │ ├── app/Chart.yaml │ └── api/Chart.yaml └── ingress/ingress.yaml

👍 You want to add deployment and service Helm templates for app and api under your given structure.

Here’s the updated tree and the actual templates/ files:

📂 Updated Project Structure

eks-alb-starter/
├── README.md
├── terraform/
│   ├── backend.tf
│   ├── providers.tf
│   ├── vpc.tf
│   ├── eks-cluster.tf
│   ├── alb-controller.tf
│   ├── route53-acm.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
└── k8s/
    ├── helm-values/
    │   ├── app/values.yaml
    │   └── api/values.yaml
    ├── charts/
    │   ├── app/
    │   │   ├── Chart.yaml
    │   │   └── templates/
    │   │       ├── deployment.yaml
    │   │       └── service.yaml
    │   └── api/
    │       ├── Chart.yaml
    │       └── templates/
    │           ├── deployment.yaml
    │           └── service.yaml
    └── ingress/ingress.yaml

📌 charts/app/templates/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-deployment
  namespace: {{ .Values.namespace | default "microservices" }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}-container
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          ports:
            - containerPort: {{ .Values.service.port }}


📌 charts/app/templates/service.yaml

apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-service
  namespace: {{ .Values.namespace | default "microservices" }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
  selector:
    app: {{ .Chart.Name }}


📌 charts/api/templates/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-deployment
  namespace: {{ .Values.namespace | default "microservices" }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}-container
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          ports:
            - containerPort: {{ .Values.service.port }}


📌 charts/api/templates/service.yaml


apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-service
  namespace: {{ .Values.namespace | default "microservices" }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
  selector:
    app: {{ .Chart.Name }}

✅ With this, your app and api charts are ready.
Each uses values.yaml from helm-values/app/values.yaml and helm-values/api/values.yaml.

Do you also want me to write sample values.yaml files (for both app & api) so you can deploy directly with helm install?


