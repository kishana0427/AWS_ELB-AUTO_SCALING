output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}


output "acm_cname_name" {
  value = tolist(aws_acm_certificate.app_cert.domain_validation_options)[0].resource_record_name
}

output "acm_cname_value" {
  value = tolist(aws_acm_certificate.app_cert.domain_validation_options)[0].resource_record_value
}


###### OR #####

#output "acm_validation_records" {
#  value = [
#    for dvo in aws_acm_certificate.app_cert.domain_validation_options : {
#      domain_name = dvo.domain_name
#      cname_name  = dvo.resource_record_name
#      cname_value = dvo.resource_record_value
#    }
#  ]
#}





#output "acm_cname_name" {
#  value = aws_acm_certificate.app_cert.domain_validation_options[0].resource_record_name
#}

#output "acm_cname_value" {
#  value = aws_acm_certificate.app_cert.domain_validation_options[0].resource_record_value
#}

########## OR ###
#output "acm_validation_records" {
#  value = [
#    for dvo in aws_acm_certificate.app_cert.domain_validation_options : {
#      domain_name = dvo.domain_name
#      cname_name  = dvo.resource_record_name
#      cname_value = dvo.resource_record_value
#    }
#  ]
#}
