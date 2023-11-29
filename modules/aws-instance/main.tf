data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids

  #added public IP
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    echo "Installing Pat's Google Maps Application"
    yum update -y
    yum install docker -y
    systemctl start docker 
    systemctl enable docker
    chmod 666 /var/run/docker.sock
    docker run --rm -d -p 80:80 -p 443:443 --name myweb patrickabrennan/myweb
    echo "Completed Installing Pat's Google Maps Application"
    # #!/bin/bash
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
