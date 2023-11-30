# establish our provider
provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
}
# create our vpc
resource "aws_vpc" "main-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}
# create our internet gateway to allow traffic in/out of our vpc
resource "aws_internet_gateway" "main-gw" {
  vpc_id = "aws_vpc.main-vpc.id"
  tags = {
    Name = "main-gw"
  }
}
# create 2 public subnets for fault tolerance
resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = "aws_vpc.main-vpc.id"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}
resource "aws_subnet" "public-subnet-2" {
  vpc_id                  = "aws_vpc.main-vpc.id"
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

# create a security group that will allow ALL HTTP traffic to enter
resource "aws_security_group" "allow-http" {
  name        = "allow-http"
  description = "allows HTTP traffic to enter security group"
  vpc_id      = "aws_vpc.main-vpc.id"
  # create an ingress rule to allow ALL HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # create an egress rule to allow ALL traffic to leave the security group
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "HTTP security group"
  }
}

# after, we'll create our EC2 instance to host a web server
# note: your ami may be different than mine
resource "aws_instance" "web server" {
  ami                    = "ami-0fc5d935ebf8bc3bc"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public-subnet-1.id
  vpc_security_group_ids = [aws_security_group.allow-http.id]
  tags = {
    Name = "Web Server"
  }
}

# next we'll create a route table and define our route to the internet gateway 
# and allow outbound internet access  
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-gw.id
  }
}
# then create 2 route table association resource which will ensure our public
# subnets are associated with a route table, and that includes a route to the Internet Gateway
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.public_route_table.id
}

# after that, we'll create an application load balancer and target group
# the application load balancer will evenly distribute traffic across multiple
# targets described in the target group
resource "aws_lb" "web_alb" {
  name                       = "web_alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.allow-http.id]
  subnets                    = [aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id]
  enable_deletion_protection = false
}
resource "aws_lb_target_group" "web_tg" {
  name     = "web_tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main-vpc.id
}

# moving on, we'll create an auto-scaling group to automatically adjust the number of EC2 instances
resource "aws_autoscaling_group" "web_asg" {
  launch_configuration = aws_launch_configuration.web_config.id
  vpc_zone_identifier  = [aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id]
  target_group_arns    = [aws_lb_target_group.web_tg.arn]
  min_size             = 1
  max_size             = 3
  health_check_type    = "ELB"

  tag {
    key                 = "Name"
    value               = "WebServerInstance"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "web_config" {
  name          = "web-launch-config"
  image_id      = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}

