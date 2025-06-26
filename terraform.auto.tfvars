aws_region             = "us-east-2"
project = {
  frontend = {
    environment = "dev"
  },
  backend = {
    environment = "prod"
  }
}
acm_certificate_arn = "arn:aws:acm:us-east-2:285942769742:certificate/c8842388-a5db-414d-9378-a98d4642455b"

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
