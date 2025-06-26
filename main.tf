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
  flattened_projects = flatten([
    for project_key, project in var.project : [
      {
        key                         = project_key
        environment                 = project.environment
        private_subnets_per_vpc     = project.private_subnets_per_vpc
        public_subnets_per_vpc      = project.public_subnets_per_vpc
        instances_per_subnet        = project.instances_per_subnet
        instance_type               = project.instance_type
      }
    ]
  ])
}

##NEW VPC Module ADDED 6/25/25
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  for_each = { for p in local.flattened_projects : p.key => p }

  cidr = var.vpc_cidr_block
  azs  = data.aws_availability_zones.available.names

  private_subnets = slice(var.private_subnet_cidr_blocks, 0, each.value.private_subnets_per_vpc)
  public_subnets  = slice(var.public_subnet_cidr_blocks, 0, each.value.public_subnets_per_vpc)

  enable_nat_gateway      = true
  enable_vpn_gateway      = false
  map_public_ip_on_launch = false
}

module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "4.9.0"
  #module "https_443_security_group" {
  #source  = "terraform-aws-modules/security-group/aws//modules/https-443"
  #version = "~> 5.0"

  #Added 11/28/2023 
  for_each = var.project

  #Added 11/28/2023
  name        = "web-server-sg-${each.key}-${each.value.environment}"

  #commented out
  #name        = "web-server-sg-${var.project_name}-${var.environment}"
  description = "Security group for web-servers with HTTP ports open within VPC"


  #Added 11/28/
  vpc_id      = module.vpc[each.key].vpc_id
  #commented out 11/28/2023
  #vpc_id      = module.vpc.vpc_id

  #Added 11/28/2023
  ingress_cidr_blocks = module.vpc[each.key].public_subnets_cidr_blocks
  #Commented out 11/28/2023 
  #ingress_cidr_blocks = module.vpc.public_subnets_cidr_blocks
}

module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "4.9.0"
  
  for_each = var.project

  name = "load-balancer-sg-${each.key}-${each.value.environment}"

  description = "Security group for load balancer with HTTP ports open within VPC"

  vpc_id      = module.vpc[each.key].vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}


#ADDED 6/25/2024
# random string for uniqueness
resource "random_string" "lb_id" {
  length  = 6
  upper   = false
  lower   = true
  number  = true
  special = false
}

#ADDED LOCAL 6-25-25
# Local for ELB name generation
locals {
  elb_names = {
    for k, v in var.project :
    k => trimsuffix(
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
  #Chaged for each code 6-25-25
  for_each = { for p in local.flattened_projects : p.key => p }
  #for_each = var.project

  name     = local.elb_names[each.key]
  internal = false

  security_groups = [module.lb_security_group[each.key].security_group_id]
  subnets         = module.vpc[each.key].public_subnets

  number_of_instances = length(module.ec2_instances[each.key].instance_ids)
  instances           = module.ec2_instances[each.key].instance_ids

  listener = [{
    instance_port      = "80"
    instance_protocol  = "HTTP"
    lb_port            = "443"
    lb_protocol        = "HTTPS"
    ssl_certificate_id = var.acm_certificate_arn
  }]
}

  health_check = {
    #Commented out port 80
    target              = "HTTP:80/index.html"
    #Added port 443
    #target              = "HTTP:443/index.html"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
  }
#}

#ADDED  12-19-2023
resource "aws_route53_record" "tf-demo" {
  zone_id = "Z08017432VFWFXO6IWHIK"
  #name    = var.aws_dns_name
  name = "maps.demo.pabrennan.com"
  type    = "CNAME"
  ttl     = 300
  records = [module.elb_http["client-webapp"].elb_dns_name]
}


#NEW EC2_INSTANCES MODULE 6/25/25
module "ec2_instances" {
  source     = "./modules/aws-instance"
  depends_on = [module.vpc]

  for_each = { for p in local.flattened_projects : p.key => p }

  instance_count     = each.value.instances_per_subnet * length(module.vpc[each.key].private_subnets)
  instance_type      = each.value.instance_type
  subnet_ids         = module.vpc[each.key].private_subnets[*]
  security_group_ids = [module.app_security_group[each.key].security_group_id]

  project_name = each.key
  environment  = each.value.environment
}

#Comment out data "aws_ami" "amazon_linux" 11/28/2023 as will be using a module
#data "aws_ami" "amazon_linux" {
#  most_recent = true
#  owners      = ["amazon"]

#  filter {
#    name   = "name"
#    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#  }
#}

#Comment out resource "aws_instance" "app" as will be using a module
#resource "aws_instance" "app" {
#  count = 2

#  ami           = data.aws_ami.amazon_linux.id
#  instance_type = var.instance_type

#  subnet_id              = module.vpc.private_subnets[0]
#  vpc_security_group_ids = [module.app_security_group.security_group_id]

#  user_data = <<-EOF
#    #!/bin/bash
#    sudo yum update -y
#    sudo yum install httpd -y
#    sudo systemctl enable httpd
#    sudo systemctl start httpd
#    echo "<html><body><div>Hello, world!</div></body></html>" > /var/www/html/index.html
#    EOF

#  tags = {
#    Terraform   = "true"
#    Project     = var.project_name
#    Environment = var.environment
#  }
#}
