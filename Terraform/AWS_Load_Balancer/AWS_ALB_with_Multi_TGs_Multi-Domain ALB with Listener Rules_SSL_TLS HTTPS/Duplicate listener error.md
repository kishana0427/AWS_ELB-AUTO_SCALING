aws_lb_listener.http: Creating... ╷ │ Error: creating ELBv2 Listener (arn:aws:elasticloadbalancing:ap-south-1:440878854771:loadbalancer/app/app-lb/1c3818cf6bdc8945): operation error Elastic Load Balancing v2: CreateListener, https response error StatusCode: 400, RequestID: 17dea2b2-0884-43d2-895d-d4f1fead9ba8, DuplicateListener: A listener already exists on this port for this load balancer 'arn:aws:elasticloadbalancing:ap-south-1:440878854771:loadbalancer/app/app-lb/1c3818cf6bdc8945' │ │ with aws_lb_listener.http, │ on main.tf line 166, in resource "aws_lb_listener" "http": │ 166: resource "aws_lb_listener" "http" {


The error you’re getting:

DuplicateListener: A listener already exists on this port for this load balancer


means your Application Load Balancer (app-lb) already has a listener configured on the same port (most likely port 80 for HTTP or 443 for HTTPS). Terraform is trying to create another listener on the same port, which AWS does not allow.



✅ Fix Options
1. Check for an Existing Listener in Terraform State

Run:

terraform state list | grep aws_lb_listener


If you see an existing listener (aws_lb_listener.http or something else), that means Terraform already manages one on that port.

👉 If you accidentally defined it twice in your .tf files, remove the duplicate block.

2. Check in AWS Console

Go to EC2 → Load Balancers → app-lb → Listeners.

If port 80 or 443 already exists, remove it manually or import it into Terraform.

3. Import Existing Listener into Terraform (Recommended if created outside TF)

If you created the listener manually in AWS (or another Terraform run), import it:

terraform import aws_lb_listener.http arn:aws:elasticloadbalancing:ap-south-1:440878854771:listener/app/app-lb/1c3818cf6bdc8945/xxxxxxxxx/yyyyyyyyy

(Replace with the actual listener ARN, not the LB ARN).

4. Change Port if Intentional

If you’re trying to create two different listeners, change the port in your Terraform:

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 8080   # instead of 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

⚡ Common Cause:
Most times, people already define a default listener when creating the ALB (via module or resource), then add another aws_lb_listener manually on the same port → conflict.

👉 Can you share your aws_lb_listener block (line 166 in main.tf)? I can adjust it for your setup so Terraform won’t try to duplicate the listener.



provider "aws" { region = "ap-south-1" # change to your preferred region } # VPC resource "aws_vpc" "main" { cidr_block = "10.0.0.0/16" } # Internet Gateway resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.main.id } # Subnets resource "aws_subnet" "public_a" { vpc_id = aws_vpc.main.id cidr_block = "10.0.1.0/24" availability_zone = "ap-south-1a" map_public_ip_on_launch = true } resource "aws_subnet" "public_b" { vpc_id = aws_vpc.main.id cidr_block = "10.0.2.0/24" availability_zone = "ap-south-1b" map_public_ip_on_launch = true } # Route Table resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id } resource "aws_route" "default_route" { route_table_id = aws_route_table.public.id destination_cidr_block = "0.0.0.0/0" gateway_id = aws_internet_gateway.igw.id } resource "aws_route_table_association" "a" { subnet_id = aws_subnet.public_a.id route_table_id = aws_route_table.public.id } resource "aws_route_table_association" "b" { subnet_id = aws_subnet.public_b.id route_table_id = aws_route_table.public.id } # Security Group resource "aws_security_group" "web_sg" { vpc_id = aws_vpc.main.id name = "web-sg" ingress { description = "Allow HTTP" from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] } ingress { description = "Allow SSH" from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] } egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] } } resource "aws_security_group" "alb_sg" { vpc_id = aws_vpc.main.id name = "alb-sg" ingress { description = "Allow HTTP" from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] } egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] } } # Launch EC2 Instances (Sample Web App) resource "aws_instance" "web_a" { ami = "ami-0861f4e788f5069dd" # Amazon Linux 2 AMI (check latest) instance_type = "t2.micro" subnet_id = aws_subnet.public_a.id key_name = "mrcet-key" vpc_security_group_ids = [aws_security_group.web_sg.id] user_data = <<-EOF #!/bin/bash yum install -y httpd echo "<h1>Hello from Web A</h1>" > /var/www/html/index.html systemctl start httpd systemctl enable httpd EOF } resource "aws_instance" "web_b" { ami = "ami-0861f4e788f5069dd" instance_type = "t2.micro" subnet_id = aws_subnet.public_b.id key_name = "mrcet-key" vpc_security_group_ids = [aws_security_group.web_sg.id] user_data = <<-EOF #!/bin/bash yum install -y httpd echo "<h1>Hello from Web B</h1>" > /var/www/html/index.html systemctl start httpd systemctl enable httpd EOF } # ALB resource "aws_lb" "app_lb" { name = "app-lb" internal = false load_balancer_type = "application" security_groups = [aws_security_group.alb_sg.id] subnets = [aws_subnet.public_a.id, aws_subnet.public_b.id] } # Target Group resource "aws_lb_target_group" "app_tg" { name = "app-tg" port = 80 protocol = "HTTP" vpc_id = aws_vpc.main.id } # Attach Instances to Target Group resource "aws_lb_target_group_attachment" "web_a" { target_group_arn = aws_lb_target_group.app_tg.arn target_id = aws_instance.web_a.id port = 80 } resource "aws_lb_target_group_attachment" "web_b" { target_group_arn = aws_lb_target_group.app_tg.arn target_id = aws_instance.web_b.id port = 80 } # Listener resource "aws_lb_listener" "http" { load_balancer_arn = aws_lb.app_lb.arn port = "80" protocol = "HTTP" default_action { type = "forward" target_group_arn = aws_lb_target_group.app_tg.arn } } # Route53 DNS record (optional - replace with your hosted zone ID & domain) #resource "aws_route53_record" "app_record" { # zone_id = "ZXXXXXXXXXXXX" # Replace with your hosted zone ID # name = "app.example.com" # type = "A" # alias { # name = aws_lb.app_lb.dns_name # zone_id = aws_lb.app_lb.zone_id # evaluate_target_health = true # } #} # Request ACM Certificate for your domain resource "aws_acm_certificate" "app_cert" { domain_name = "krish.kozow.com" # Replace with your domain validation_method = "DNS" } # Validate certificate resource "aws_acm_certificate_validation" "app_cert_validation" { certificate_arn = aws_acm_certificate.app_cert.arn validation_record_fqdns = [krish.kozow.com] } # HTTPS Listener (443) with ACM Certificate resource "aws_lb_listener" "https" { load_balancer_arn = aws_lb.app_lb.arn port = "443" protocol = "HTTPS" ssl_policy = "ELBSecurityPolicy-2016-08" certificate_arn = aws_acm_certificate_validation.app_cert_validation.certificate_arn default_action { type = "forward" target_group_arn = aws_lb_target_group.app_tg.arn } } # Redirect HTTP → HTTPS resource "aws_lb_listener" "http_redirect" { load_balancer_arn = aws_lb.app_lb.arn port = "80" protocol = "HTTP" default_action { type = "redirect" redirect { port = "443" protocol = "HTTPS" status_code = "HTTP_301" } } } check my code



Thanks for pasting the full Terraform code 👍.

I see why you’re hitting DuplicateListener error:

You already have two listeners defined on port 80:

aws_lb_listener.http (forwards to target group)

aws_lb_listener.http_redirect (redirects to HTTPS)

AWS does not allow two listeners on the same port (80) for the same ALB.

🔧 Fix

You need to decide whether you want:

Option 1: HTTP → HTTPS Redirect (recommended)

Keep only http_redirect and delete http listener.
This way, all traffic hitting http:// will be redirected to https://.



# REMOVE this block
# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = "80"
#   protocol          = "HTTP"
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }



Keep only:


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

  
  Option 2: Keep Plain HTTP (no redirect)

Delete the http_redirect resource, keep the http listener that forwards traffic directly to your target group.

⚠️ One More Issue in Your Code

This line will also fail:

validation_record_fqdns = [krish.kozow.com]


Terraform will think krish is a variable (undefined).
It should be a string, like:

validation_record_fqdns = ["krish.kozow.com"]

But actually, for ACM DNS validation, you normally use aws_route53_record or manually add DNS records. You can’t just drop the domain name here without validation records.

✅ So the immediate fix:

Remove one of the two port 80 listeners.

Fix validation_record_fqdns with quotes (and probably configure Route53 for validation properly).

👉 Do you want me to clean up your code so it’s HTTPS-only with redirect from HTTP, and proper ACM certificate validation via DNS record?



how to print CNAME name and CNAME value of ACM with output


Good question 👍

When you create an ACM certificate with validation_method = "DNS", AWS generates a CNAME record (Name + Value) that you must add in your DNS (Route53, Dynu, Kozow, etc.) to validate the certificate.

Terraform exposes this inside:

aws_acm_certificate.app_cert.domain_validation_options


That attribute is a list of objects, each with:

domain_name

resource_record_name → CNAME Name

resource_record_type → CNAME type (CNAME)

resource_record_value → CNAME Value

✅ Example: Output ACM CNAME

Add this to your Terraform:

output "acm_validation_records" {
  value = [
    for dvo in aws_acm_certificate.app_cert.domain_validation_options : {
      domain_name = dvo.domain_name
      cname_name  = dvo.resource_record_name
      cname_value = dvo.resource_record_value
    }
  ]
}


When you run:
terraform apply
terraform output acm_validation_records



You’ll see something like:

[
  {
    "domain_name" = "krish.kozow.com"
    "cname_name"  = "_abcd1234.krish.kozow.com."
    "cname_value" = "_xyz987.acm-validations.aws."
  }
]

✅ If You Want Separate Outputs

You can also output just the CNAME Name and Value:

output "acm_cname_name" {
  value = aws_acm_certificate.app_cert.domain_validation_options[0].resource_record_name
}

output "acm_cname_value" {
  value = aws_acm_certificate.app_cert.domain_validation_options[0].resource_record_value
}


⚠️ Note: If you request a certificate for multiple domains (like example.com + www.example.com), you’ll get multiple records, so the for loop version is safer.

👉 Do you want me to also add an aws_route53_record block so Terraform automatically creates the DNS validation record instead of printing and adding manually?




 Error: Invalid index
│
│   on outputs.tf line 6, in output "acm_cname_name":
│    6:   value = aws_acm_certificate.app_cert.domain_validation_options[0].resource_record_name
│
│ Elements of a set are identified only by their value and don't have any separate index or key to select with, so it's only possible
│ to perform operations across all elements of the set.
╵
╷
│ Error: Invalid index
│
│   on outputs.tf line 10, in output "acm_cname_value":
│   10:   value = aws_acm_certificate.app_cert.domain_validation_options[0].resource_record_value
│
│ Elements of a set are identified only by their value and don't have any separate index or key to select with, so it's only possible
│ to perform operations across all elements of the set.
ChatGPT said:

Ah 👍 this is a common Terraform gotcha.
domain_validation_options is returned as a set of objects → sets in Terraform don’t support indexing (like [0]).

That’s why you’re getting the Invalid index error.

✅ Fix: Convert the set to a list

You can wrap it in tolist() before indexing:


output "acm_cname_name" {
  value = tolist(aws_acm_certificate.app_cert.domain_validation_options)[0].resource_record_name
}

output "acm_cname_value" {
  value = tolist(aws_acm_certificate.app_cert.domain_validation_options)[0].resource_record_value
}


✅ Better Fix: Use a for-expression (works with multiple domains too)

output "acm_validation_records" {
  value = [
    for dvo in aws_acm_certificate.app_cert.domain_validation_options : {
      domain_name = dvo.domain_name
      cname_name  = dvo.resource_record_name
      cname_value = dvo.resource_record_value
    }
  ]
}


That way, you’ll get all validation CNAMEs (if you requested multiple SANs/domains).

Example Output

After terraform apply:

acm_validation_records = [
  {
    "domain_name" = "krish.kozow.com"
    "cname_name"  = "_abcd1234.krish.kozow.com."
    "cname_value" = "_xyz987.acm-validations.aws."
  }
]


👉 Do you want me to also show you how to automatically create these CNAMEs in Route53 (so you don’t need to copy/paste manually)?

