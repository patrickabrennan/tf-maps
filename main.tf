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

# ADDED 6/25/2025
locals {
  flattened_projects = [
    for project_key, project in var.project : {
      key                     = project_key
      environment             = project.environment
      private_subnets_per_vpc = project.private_subnets_per_vpc
      public_subnets_per_vpc  = project.public_subnets_per_vpc
      instances_per_subnet    = project.instances_per_subnet
      instance_type           = project.instance_type
    }
  ]

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

# NEW VPC MODULE ADDED 6/27/2025
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

  create_igw             = each.value.public_subnets_per_vpc > 0
  enable_nat_gateway     = each.value.private_subnets_per_vpc > 0 && each.value.public_subnets_per_vpc > 0
  single_nat_gateway     = true
  enable_vpn_gateway     = false
  map_public_ip_on_launch = false
}

# NEW APP SECURITY GROUP 6/27/2025
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

# LOAD BALANCER SECURITY GROUP 6/27/2025
module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "4.9.0"
  
  for_each = {
    for p in local.flattened_projects : p.key => p
    if p.private_subnets_per_vpc > 0 || p.public_subnets_per_vpc > 0
  }

  name        = "load-balancer-sg-${each.key}-${each.value.environment}"
  description = "Security group for load balancer with HTTP ports open within VPC"
  vpc_id      = module.vpc[each.key].vpc_id
  ingress_cidr_blocks = ["0.0.0.0/0"]
}

# RANDOM STRING FOR ELB NAMES
resource "random_string" "lb_id" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# ELB HTTP MODULE 6/27/2025
module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "3.0.1"

  for_each = {
    for p in local.flattened_projects : p.key => p
    if p.public_subnets_per_vpc > 0 || p.private_subnets_per_vpc > 0
  }

  name     = local.elb_names[each.key]

  internal = each.value.public_subnets_per_vpc == 0

  subnets = concat(
    module.vpc[each.key].public_subnets,
    module.vpc[each.key].private_subnets
  )

  security_groups    = [module.lb_security_group[each.key].security_group_id]
  instances          = module.ec2_instances[each.key].instance_ids
  number_of_instances = length(module.ec2_instances[each.key].instance_ids)

  # Listeners - listen on HTTP (80) and HTTPS (443)
  listener = [
    {
      instance_port     = 80
      instance_protocol = "http"
      lb_port           = 80
      lb_protocol       = "http"
      ssl_certificate_id = "" # leave empty or specify if you want SSL termination on ELB
    },
    {
      instance_port     = 443
      instance_protocol = "https"
      lb_port           = 443
      lb_protocol       = "https"
      ssl_certificate_id = var.ssl_certificate_arn  # You must provide this ARN in variables if you want HTTPS
    }
  ]

  health_check = {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:80/"
    interval            = 30
  }

  depends_on = [module.ec2_instances]
}



#module "elb_http" {
#  source  = "terraform-aws-modules/elb/aws"
#  version = "3.0.1"

#  for_each = {
#    for p in local.flattened_projects : p.key => p
#    if p.public_subnets_per_vpc > 0 || p.private_subnets_per_vpc > 0
#  }

#  name     = local.elb_names[each.key]

#  # ELB is internal if no public subnets
#  internal = each.value.public_subnets_per_vpc == 0

#  # Attach to all public + private subnets available
#  subnets = concat(
#    module.vpc[each.key].public_subnets,
#    module.vpc[each.key].private_subnets
#  )

#  security_groups    = [module.lb_security_group[each.key].security_group_id]
#  instances          = module.ec2_instances[each.key].instance_ids
#  number_of_instances = length(module.ec2_instances[each.key].instance_ids)

#  # Example listeners and health check (customize as needed)
#  listener = {
#    instance_port     = 80
#    instance_protocol = "http"
#    lb_port           = 80
#    lb_protocol       = "http"
#  }

#  health_check = {
#    healthy_threshold   = 2
#    unhealthy_threshold = 2
#    timeout             = 3
#    target              = "HTTP:80/"
#    interval            = 30
#  }

#  depends_on = [module.ec2_instances]
#}

# ROUTE53 RECORDS FOR ALL PROJECTS WITH ELB
resource "aws_route53_record" "project_records" {
  for_each = module.elb_http

  zone_id = "Z08017432VFWFXO6IWHIK" # Replace with your zone ID or variable

  name = local.elb_names[each.key]

  type = "A"

  alias {
    name                   = each.value.elb_dns_name
    zone_id                = each.value.elb_zone_id
    evaluate_target_health = true
  }
}

# EC2 INSTANCE MODULE 6/27/2025
module "ec2_instances" {
  source     = "./modules/aws-instance"
  depends_on = [module.vpc]

  for_each = {
    for p in local.flattened_projects : p.key => p
    if p.private_subnets_per_vpc > 0 || p.public_subnets_per_vpc > 0
  }

  instance_count = each.value.instances_per_subnet * (
    each.value.private_subnets_per_vpc > 0
      ? length(module.vpc[each.key].private_subnets)
      : length(module.vpc[each.key].public_subnets)
  )

  subnet_ids = (
    each.value.private_subnets_per_vpc > 0
      ? module.vpc[each.key].private_subnets
      : module.vpc[each.key].public_subnets
  )

  instance_type      = each.value.instance_type
  security_group_ids = [module.app_security_group[each.key].security_group_id]
  project_name       = each.key
  environment        = each.value.environment
  ssh_key_name       = var.ssh_key_name
}

# SSH KEYPAIR RESOURCE 6/26/2025
resource "aws_key_pair" "deployer" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key
}
