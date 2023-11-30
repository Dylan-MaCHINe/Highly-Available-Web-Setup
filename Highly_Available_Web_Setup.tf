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
