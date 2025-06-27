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
  description = "The AWS-assigned DNS name of the maps load balancer"
  value       = module.elb_http["backend"].elb_dns_name
}

output "maps_elb_zone_id" {
  description = "The zone ID of the load balancer, used for Route53 alias"
  value       = module.elb_http["backend"].elb_zone_id
}

output "vpc_arns" {
  value = { for p in sort(keys(module.vpc)) : p => module.vpc[p].vpc_arn }
  description = "VPC ARNs per project"
}

output "instance_ids" {
  value = { for p in sort(keys(module.ec2_instances)) : p => module.ec2_instances[p].instance_ids }
  description = "EC2 instance IDs per project"
}
