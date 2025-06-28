provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

##ADDED 6/25/2025
locals {
  flattened_projects = [
    for project_key, project in var.project : {
      key                         = project_key
      environment                 = project.environment
      private_subnets_per_vpc     = project.private_subnets_per_vpc
      public_subnets_per_vpc      = project.public_subnets_per_vpc
      instances_per_subnet        = project.instances_per_subnet
      instance_type               = project.instance_type
    }
  ]
}

#NEW VPC MODUKE ADDED 6/27/2025
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  for_each = {
    for p in local.flattened_projects : p.key => p
    if p.private_subnets_per_vpc > 0 || p.public_subnets_per_vpc > 0
  }

  cidr = var.vpc_cidr_block
  azs  = data.aws_availability_zones.available.names

  private_subnets = slice(var.private_subnet_cidr_blocks, 0, each.value.private_subnets_per_vpc)
  public_subnets  = each.value.public_subnets_per_vpc > 0 ? slice(var.public_subnet_cidr_blocks, 0, each.value.public_subnets_per_vpc) : []

  enable_nat_gateway = each.value.public_subnets_per_vpc > 0 ? true : false
  enable_vpn_gateway = false
  map_public_ip_on_launch = false
}

#NEW VPC Module ADDED 6/25/25
#module "vpc" {
#  source  = "terraform-aws-modules/vpc/aws"
#  version = "3.14.2"

#  #for_each = { for p in local.flattened_projects : p.key => p }
##ADDED 6/27/2025
#  for_each = {
#    for p in local.flattened_projects : p.key => p
#    if p.private_subnets_per_vpc > 0 || p.public_subnets_per_vpc > 0
#  }

#  cidr = var.vpc_cidr_block
#  azs  = data.aws_availability_zones.available.names
#  private_subnets = slice(var.private_subnet_cidr_blocks, 0, each.value.private_subnets_per_vpc)
#  public_subnets  = slice(var.public_subnet_cidr_blocks, 0, each.value.public_subnets_per_vpc)
#  enable_nat_gateway      = true
#  enable_vpn_gateway      = false
#  map_public_ip_on_launch = false
#}

#NEW APP SECURITY GROUP 6/27/2025
module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  for_each = {
    for p in local.flattened_projects : p.key => p
    if p.private_subnets_per_vpc > 0 || p.public_subnets_per_vpc > 0
  }

  name        = "web-server-sg-${each.key}-${each.value.environment}"
  description = "Security group for web-servers with HTTP and SSH ports open"
  vpc_id      = module.vpc[each.key].vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Allow SSH"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow HTTP"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow HTTPS"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "4.9.0"
  
  #ADDED 6/27/2025
  #for_each = var.project
# For lb_security_group
  for_each = {
    for p in local.flattened_projects : p.key => p
    if p.private_subnets_per_vpc > 0 || p.public_subnets_per_vpc > 0
  }

#for_each = {
#    for k, v in var.project : k => v
#    if try(module.vpc[k].vpc_id, null) != null
#  }

  name = "load-balancer-sg-${each.key}-${each.value.environment}"
  description = "Security group for load balancer with HTTP ports open within VPC"
  vpc_id      = module.vpc[each.key].vpc_id
  ingress_cidr_blocks = ["0.0.0.0/0"]
}

#ADDED 6/27/2024
resource "random_string" "lb_id" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

#NEW ELB with name:
locals {
  elb_names = {
    for k, v in var.project : k =>
    k == "maps"
    ? "maps.demo.pabrennan.com"
    : trimsuffix(
        substr(
          join(
            "",
            regexall("[a-zA-Z0-9-]", join("-", ["lb", random_string.lb_id.result, k, v.environment]))
          ),
          0,
          32
        ),
        "-"
      )
  }
}

#ADDED NEW ELB MODULE
module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "3.0.1"

  for_each = {
    for p in local.flattened_projects : p.key => p
    if p.public_subnets_per_vpc > 0 || p.private_subnets_per_vpc > 0
  }

  name              = local.elb_names[each.key]
  internal          = false
  security_groups   = [module.lb_security_group[each.key].security_group_id]
  subnets           = each.value.public_subnets_per_vpc > 0 ? module.vpc[each.key].public_subnets : module.vpc[each.key].private_subnets
  number_of_instances = length(module.ec2_instances[each.key].instance_ids)
  instances           = module.ec2_instances[each.key].instance_ids

  listener = [{
    instance_port      = "80"
    instance_protocol  = "HTTP"
    lb_port            = "443"
    lb_protocol        = "HTTPS"
    ssl_certificate_id = var.ssl_certificate_id
  }]

  health_check = {
    target              = "HTTP:80/index.html"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
  }

  depends_on = [module.ec2_instances]
}



#ADDED 6/27/2025
resource "aws_route53_record" "maps" {
  count   = try(module.elb_http["backend"].elb_dns_name != "", false) ? 1 : 0
  zone_id = "Z08017432VFWFXO6IWHIK"
  name    = "maps.demo.pabrennan.com"
  type    = "A"

  alias {
    name                   = module.elb_http["backend"].elb_dns_name
    zone_id                = module.elb_http["backend"].elb_zone_id
    evaluate_target_health = true
  }
}




#NEW EC2 INSSTANCE MNODE 6/26/2025
module "ec2_instances" {
  source     = "./modules/aws-instance"
  depends_on = [module.vpc]

#Added 6/27/2025
#  for_each = { for p in local.flattened_projects : p.key => p }
  for_each = {
    for p in local.flattened_projects : p.key => p
    if p.private_subnets_per_vpc > 0
  }

  instance_count     = each.value.instances_per_subnet * length(module.vpc[each.key].private_subnets)
  instance_type      = each.value.instance_type
  subnet_ids         = module.vpc[each.key].private_subnets[*]
  security_group_ids = [module.app_security_group[each.key].security_group_id]
  project_name = each.key
  environment  = each.value.environment
  ssh_key_name = var.ssh_key_name   # Add this line
}

#ADDED 6/26/2025
resource "aws_key_pair" "deployer" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key
}
