#ADDED 6/26/2025
output "maps_dns_record_name" {
  description = "The DNS name for maps.demo.pabrennan.com Route53 record"
  value       = aws_route53_record.maps.name
}

output "maps_dns_record_fqdn" {
  description = "The FQDN created in Route53 for maps"
  value       = aws_route53_record.maps.fqdn
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
  description = "ARNs of the vpcs for each project."
  value       = { for p in sort(keys(var.project)) : p => module.vpc[p].vpc_arn }
}

output "instance_ids" {
  description = "IDs of EC2 instances."
  value       = { for p in sort(keys(var.project)) : p => module.ec2_instances[p].instance_ids }
}
