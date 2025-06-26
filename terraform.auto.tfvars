aws_region             = "us-east-2"
project = {
  frontend = {
    environment = "dev"
  },
  backend = {
    environment = "prod"
  }
}
acm_certificate_arn = "arn:aws:acm:us-east-2:278697972666:certificate/8bda4860-342f-4412-9e48-68b506054282"

#private_subnets_per_vpc = 1
#public_subnets_per_vpc = 1
#instance_type      = "t3.large"
#instances_per_subnet = 2
#instances_per_subnet = 2
#environment            = "dev"
#environment            = "test"
vpc_cidr_block = "10.0.0.0/16"
#web_identity_token_file = "identity_token.aws.jwt_filename"
#role_arn = "arn:aws:iam::285942769742:role/tfc-workload-identity"
