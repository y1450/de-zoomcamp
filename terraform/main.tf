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
