#Commented out items now that we are using for_each on 11/28/2023
#output "public_dns_name" {
#  description = "Public DNS name of load balancer"
#  value       = module.elb_http.elb_dns_name
#}

#output "vpc_arn" {
#  description = "ARN of the vpc"
#  value       = module.vpc.vpc_arn
#}

#output "instance_ids" {
#  description = "IDs of EC2 instances"
#  value       = aws_instance.app.*.id
#}
#Added below 11/28/2023
output "public_dns_names" {
  description = "Public DNS names of the load balancers for each project."
  #value       = { for p in sort(keys(var.project)) : p => module.elb_http[p].elb_dns_name }
  value       = module.elb_http[0].elb_dns_name
}

output "vpc_arns" {
  description = "ARNs of the vpcs for each project."
  value       = { for p in sort(keys(var.project)) : p => module.vpc[p].vpc_arn }
}

output "instance_ids" {
  description = "IDs of EC2 instances."
  value       = { for p in sort(keys(var.project)) : p => module.ec2_instances[p].instance_ids }
}

