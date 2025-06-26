data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#ADDED 6/26/25
resource "aws_key_pair" "deployer" {
  key_name   = "pat-key"
  public_key = file("/Users/patrick.brennan/.ssh/id_rsa.pub") # Make sure this file exists
}

resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids

  #added public IP 12/15/2023
  associate_public_ip_address = true
  
  #ADDED 6/26/2025
  key_name = aws_key_pair.deployer.key_name

  user_data = <<-EOF
    #!/bin/bash
    echo "Installing Pat's Google Maps Application"
    sudo bash -c 'yum update -y'
    sudo bash -c 'yum install docker -y'
    sudo bash -c 'systemctl start docker' 
    sudo bash -c 'systemctl enable docker'
    sudo bash -c 'chmod 666 /var/run/docker.sock'
    docker run --rm -d -p 80:80 -p 443:443 --name myweb patrickabrennan/myweb
    echo "Completed Installing Pat's Google Maps Application"
    #sudo yum update -y
    #sudo yum install httpd -y
    #sudo systemctl enable httpd
    #sudo systemctl start httpd
    #echo "<html><body><div>Hello, world!</div></body></html>" > /var/www/html/index.html
  EOF

  tags = {
    Terraform   = "true"
    Project     = var.project_name
    Environment = var.environment
  }
}
