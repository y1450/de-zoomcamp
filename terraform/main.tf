terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}
# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

// This data object is going to be
// holding all the available availability
// zones in our defined region
data "aws_availability_zones" "available" {
  state = "available"
}

# ----------- VPC ------------------
// Create a VPC named "prefect_vpc"
resource "aws_vpc" "prefect_vpc" {
  // Here we are setting the CIDR block of the VPC
  // to the "vpc_cidr_block" variable
  cidr_block           = var.vpc_cidr_block
  // We want DNS hostnames enabled for this VPC
  /* https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html */
  enable_dns_hostnames = true

  // We are tagging the VPC with the name "prefect_vpc"
  tags = {
    Name = "prefect_vpc"
  }
}


# ----------- Internet Gateway ------------------
// Create an internet gateway named "prefect_igw"
// and attach it to the "prefect_vpc" VPC
resource "aws_internet_gateway" "prefect_igw" {
  // Here we are attaching the IGW to the 
  // prefect_vpc VPC
  vpc_id = aws_vpc.prefect_vpc.id

  // We are tagging the IGW with the name prefect_igw
  tags = {
    Name = "prefect_igw"
  }
}

# ----------- Subnets ------------------

## -------- public subnet ----------------------
resource "aws_subnet" "prefect_public_subnet" {
  vpc_id            = aws_vpc.prefect_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "prefect_public_subnet"
  }
}

## ---------------- private subnet ----------------------
resource "aws_subnet" "prefect_private_subnet" {
  vpc_id            = aws_vpc.prefect_vpc.id
  cidr_block        = "10.0.101.0/24" 
  availability_zone = data.aws_availability_zones.available.names[2]
  tags = {
    Name = "prefect_private_subnet"
  }
}

# -------------- Route Tables ------------
resource "aws_route_table" "prefect_public_rt" {
  vpc_id = aws_vpc.prefect_vpc.id

  // Since this is the public route table, it will need
  // access to the internet. So we are adding a route with
  // a destination of 0.0.0.0/0 and targeting the Internet 	 
  // Gateway "prefect_igw"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prefect_igw.id
  }
}
resource "aws_route_table" "prefect_private_rt" {
  vpc_id = aws_vpc.prefect_vpc.id
  // Since this is going to be a private route table, 
  // we will not be adding a route
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.prefect_public_rt.id
  subnet_id      =  aws_subnet.prefect_public_subnet.id
}

resource "aws_route_table_association" "private" {
 
  route_table_id = aws_route_table.prefect_private_rt.id
  subnet_id      = aws_subnet.prefect_private_subnet.id
}

# ----------------- Security Groups

// Create a security for the EC2 instances called "prefect_web_sg"
resource "aws_security_group" "prefect_web_sg" {
  name        = "prefect_web_sg"
  description = "Security group for prefect web servers"
  vpc_id      = aws_vpc.prefect_vpc.id

  ingress {
    description = "Allow all traffic through HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH from my computer"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }


  // This outbound rule is allowing all outbound traffic
  // with the EC2 instances
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Here we are tagging the SG with the name "prefect_web_sg"
  tags = {
    Name = "prefect_web_sg"
  }
}


resource "aws_security_group" "prefect_db_sg" {
    name            = "prefect_db_sg"
    description     = "Security group for prefect databases"
    vpc_id          = aws_vpc.prefect_vpc.id 

    ingress {
        description         = "Allow PostgreSQL traffic from only the web sg"
        from_port           = "5432"
        to_port             = "5432"
        protocol            = "tcp"
        security_groups     = [aws_security_group.prefect_web_sg.id]
    }

    tags = {
        Name = "prefect_db_sg"
    }
} 

