#ADDED 6/27/2025
output "maps_dns_record_name" {
  value       = length(aws_route53_record.maps) > 0 ? aws_route53_record.maps[0].name : null
  description = "DNS name of the Route 53 record for maps"
}

output "maps_dns_record_fqdn" {
  value       = length(aws_route53_record.maps) > 0 ? aws_route53_record.maps[0].fqdn : null
  description = "FQDN of the Route 53 record for maps"
}

output "maps_elb_dns_name" {
  value = contains(keys(module.elb_http), "backend") ? module.elb_http["backend"].elb_dns_name : null
}

output "maps_elb_zone_id" {
  value = contains(keys(module.elb_http), "backend") ? module.elb_http["backend"].elb_zone_id : null
}

output "vpc_arns" {
  value = { for p in sort(keys(module.vpc)) : p => module.vpc[p].vpc_arn }
  description = "VPC ARNs per project"
}

output "instance_ids" {
  value = { for p in sort(keys(module.ec2_instances)) : p => module.ec2_instances[p].instance_ids }
  description = "EC2 instance IDs per project"
}
