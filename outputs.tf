#ADDED 6/27/2025
output "maps_elb_dns_name" {
  value = try(module.elb_http["backend"].elb_dns_name, null)
}

output "maps_elb_zone_id" {
  value = try(module.elb_http["backend"].elb_zone_id, null)
}

output "maps_dns_record_fqdn" {
  value = try(aws_route53_record.project_records["maps"].fqdn, null)
}

output "maps_dns_record_name" {
  value = try(aws_route53_record.project_records["maps"].name, null)
}

output "elb_dns_names" {
  value = {
    for k, r in aws_route53_record.project_records : k => r.fqdn
  }
}


output "vpc_arns" {
  value = { for p in sort(keys(module.vpc)) : p => module.vpc[p].vpc_arn }
  description = "VPC ARNs per project"
}

output "instance_ids" {
  value = { for p in sort(keys(module.ec2_instances)) : p => module.ec2_instances[p].instance_ids }
  description = "EC2 instance IDs per project"
}
