
provider "aws" {
  region     = "us-east-2"
  access_key = "enter your access key" #generate this from you AWS account
  secret_key = "enter your secret key"# generate this from you aws account
}

#1. Create a VPC
resource "aws_vpc" "project-practice" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Prod"
  }
}
#2 create internetgateway
resource "aws_internet_gateway" "gw-prod" {
  vpc_id = aws_vpc.project-practice.id

}

#3 Create a custom route table 
resource "aws_route_table" "custom-RT" {
  vpc_id = aws_vpc.project-practice.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw-prod.id
    }
  route   {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.gw-prod.id
    }
    tags = {
    Name = "Prod"
  }
}

#4 create a subnet for the server to be on
resource "aws_subnet" "sales" {
  vpc_id     = aws_vpc.project-practice.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "Production"
  }
}
#5. route table association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sales.id
  route_table_id = aws_route_table.custom-RT.id
}
#6. create a security group
resource "aws_security_group" "allow_web" {
  name        = "allow_webtraffic"
  description = "Allow WEB inbound traffic"
  vpc_id      = aws_vpc.project-practice.id

  ingress {
      description      = "HTTPs from VPC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      
    }
  ingress  {
      description      = "HTTP from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      
 }
  ingress {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      
    }

  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
 }

#7 allow netwrok interface 
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.sales.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}
#8 Create an elestic IP-Address
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw-prod]
}
# create the web server 
resource "aws_instance" "web-server1" {
  ami           = "ami-00399ec92321828f5" 
  instance_type = "t2.micro"
  availability_zone = "us-east-2a"
  key_name ="terraform"

  network_interface  {
    network_interface_id = aws_network_interface.web-server-nic.id
    device_index         = 0
  }
    
  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update 
                sudo apt-get install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web-server"
  }
}
