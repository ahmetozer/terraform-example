terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}


provider "aws" {
    alias = "eu-central-1"
    region = "eu-central-1"
}

data "aws_region" "current" {}
data "aws_availability_zones" "available" {}


resource "aws_vpc" "kadikoy" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name ="kadikoy"
  }
}

output "kadikoy_ipv6_cidr_block" {
  value=aws_vpc.kadikoy.ipv6_cidr_block
}


resource "aws_subnet" "public_subnet" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = "${aws_vpc.kadikoy.id}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.kadikoy.ipv6_cidr_block, 8, 0+count.index)}"
  ipv6_native = true
  map_public_ip_on_launch = false
  assign_ipv6_address_on_creation = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_dns64 = false
  tags={
    Name = format("%s-%s-%s",aws_vpc.kadikoy.tags.Name,"nat64",count.index)
    IPv4 = "false"
    IPv6 = "true"
    IPv6Egress = "direct"
    IPv4Egress = "nat"
  }
}