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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  for_each = var.project

  cidr = var.vpc_cidr_block

  azs             = data.aws_availability_zones.available.names

  #Added 11/28/2023 to support for_each
  private_subnets = slice(var.private_subnet_cidr_blocks, 0, each.value.private_subnets_per_vpc)
  public_subnets  = slice(var.public_subnet_cidr_blocks, 0, each.value.public_subnets_per_vpc)

  #Commented out 11/28/2023
  #private_subnets = slice(var.private_subnet_cidr_blocks, 0, var.private_subnets_per_vpc)
  #public_subnets  = slice(var.public_subnet_cidr_blocks, 0, var.public_subnets_per_vpc)


  enable_nat_gateway = true
  enable_vpn_gateway = false

  map_public_ip_on_launch = false
}

module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "4.9.0"

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

  #Added 11/28/2023
  for_each = var.project


  #Added 11/28/2023
  name = "load-balancer-sg-${each.key}-${each.value.environment}"
  #Commented out 11/28/2023
  #name = "load-balancer-sg-${var.project_name}-${var.environment}"

  description = "Security group for load balancer with HTTP ports open within VPC"
  #Added 11/28/2023
  vpc_id      = module.vpc[each.key].vpc_id
  #Commented out 11/28/2023
  #vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

resource "random_string" "lb_id" {
  length  = 4
  special = false
}

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "3.0.1"

  #Added 11/28/2023
  for_each = var.project

  # Comply with ELB name restrictions
  # https://docs.aws.amazon.com/elasticloadbalancing/2012-06-01/APIReference/API_CreateLoadBalancer.html


  #Added 11/28/2023
  name     = trimsuffix(substr(replace(join("-", ["lb", random_string.lb_id.result, each.key, each.value.environment]), "/[^a-zA-Z0-9-]/", ""), 0, 32), "-")
  #Commented out 11/28/2023
  #name     = trimsuffix(substr(replace(join("-", ["lb", random_string.lb_id.result, var.project_name, var.environment]), "/[^a-zA-Z0-9-]/", ""), 0, 32), "-")
  internal = false

  security_groups = [module.lb_security_group.security_group_id]
  subnets         = module.vpc.public_subnets

  #Added 11/28/2023
  number_of_instances = length(module.ec2_instances[each.key].instance_ids)
  instances           = module.ec2_instances[each.key].instance_ids

  #Commented out 11/28/2023
  #number_of_instances = length(aws_instance.app)
  #instances           = aws_instance.app.*.id

  listener = [{
    instance_port     = "80"
    instance_protocol = "HTTP"
    lb_port           = "80"
    lb_protocol       = "HTTP"
  }]

  health_check = {
    target              = "HTTP:80/index.html"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
  }
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
