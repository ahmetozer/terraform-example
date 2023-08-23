terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.7.0"
    }
  }

  required_version = ">= 1.2.0"
}


variable "Project" {
  type    = string
  default = "kadikoy"
}
provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"
}

data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

resource "aws_vpc" "kadikoy" {
  cidr_block                       = "10.20.0.0/16"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "${var.Project}"
  }
}

output "neighbourhood_ipv6_cidr_block" {
  value = aws_vpc.kadikoy.ipv6_cidr_block
}

# Internet Gateway
resource "aws_internet_gateway" "kadikoy" {
  vpc_id = aws_vpc.kadikoy.id
  tags = {
    "Name" = "${var.Project}-igw"
  }

  depends_on = [aws_vpc.kadikoy]
}

resource "aws_default_route_table" "kadikoy" {
  provider               = aws
  default_route_table_id = aws_vpc.kadikoy.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kadikoy.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.kadikoy.id
  }

  tags = {
    Name = format("%s-%s-%s", var.Project, "ds", "default")
  }

  depends_on = [aws_vpc.kadikoy]
}


resource "aws_egress_only_internet_gateway" "kadikoy" {
  vpc_id = aws_vpc.kadikoy.id

  tags = {
    Name = format("%s-%s", var.Project, "eigw")
  }
  depends_on = [aws_vpc.kadikoy]
}

resource "aws_route_table" "kadikoy_egress_only" {
  route {
    ipv6_cidr_block = "::/0"
    #gateway_id      = aws_egress_only_internet_gateway.kadikoy.id
    egress_only_gateway_id = aws_egress_only_internet_gateway.kadikoy.id
  }
  vpc_id = aws_vpc.kadikoy.id
  tags = {
    Name = format("%s-%s", var.Project, "egress_only")
  }
  depends_on = [aws_vpc.kadikoy]
}

resource "aws_route_table" "kadikoy_private" {

  vpc_id = aws_vpc.kadikoy.id
  tags = {
    Name = format("%s-%s", var.Project, "private")
  }
  depends_on = [aws_vpc.kadikoy]
}


resource "aws_subnet" "kadikoy_ipv6_public" {
  count                                          = length(data.aws_availability_zones.available.names)
  vpc_id                                         = aws_vpc.kadikoy.id
  availability_zone                              = data.aws_availability_zones.available.names[count.index]
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.kadikoy.ipv6_cidr_block, 8, (1 * length(data.aws_availability_zones.available.names)) + count.index)
  ipv6_native                                    = true
  map_public_ip_on_launch                        = false
  assign_ipv6_address_on_creation                = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_dns64                                   = true
  tags = {
    Name           = format("%s-%s-%s-%s", var.Project, "v6", "public", count.index + 1)
    IPv4           = "false"
    IPv6           = "true"
    IPv6EgressType = "direct"
    IPv4EgressType = "nat"
  }
}

resource "aws_subnet" "kadikoy_ipv6_egress_only" {
  count                                          = length(data.aws_availability_zones.available.names)
  vpc_id                                         = aws_vpc.kadikoy.id
  availability_zone                              = data.aws_availability_zones.available.names[count.index]
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.kadikoy.ipv6_cidr_block, 8, (2 * length(data.aws_availability_zones.available.names)) + count.index)
  ipv6_native                                    = true
  map_public_ip_on_launch                        = false
  assign_ipv6_address_on_creation                = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_dns64                                   = true
  tags = {
    Name           = format("%s-%s-%s-%s", var.Project, "v6", "egress", count.index + 1)
    IPv4           = "false"
    IPv6           = "true"
    IPv6EgressType = "direct"
    IPv4EgressType = "nat"
  }
}

resource "aws_route_table_association" "kadikoy_ipv6_egress_only_rtba" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.kadikoy_ipv6_egress_only[count.index].id
  route_table_id = aws_route_table.kadikoy_egress_only.id
}

resource "aws_subnet" "kadikoy_ipv6_private" {
  count                                          = length(data.aws_availability_zones.available.names)
  vpc_id                                         = aws_vpc.kadikoy.id
  availability_zone                              = data.aws_availability_zones.available.names[count.index]
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.kadikoy.ipv6_cidr_block, 8, (3 * length(data.aws_availability_zones.available.names)) + count.index)
  ipv6_native                                    = true
  map_public_ip_on_launch                        = false
  assign_ipv6_address_on_creation                = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_dns64                                   = false

  tags = {
    Name       = format("%s-%s-%s-%s", var.Project, "v6", "private", count.index + 1)
    IPv4       = "false"
    IPv6       = "true"
    IPv6Egress = "block"
    IPv4Egress = "block"
  }
}
resource "aws_route_table_association" "kadikoy_ipv6_private_rtba" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.kadikoy_ipv6_private[count.index].id
  route_table_id = aws_route_table.kadikoy_private.id
}



// Dual Stack
output "name" {
  value = cidrsubnet(aws_vpc.kadikoy.cidr_block, 8, (10 * length(data.aws_availability_zones.available.names)) + 2)

}
resource "aws_subnet" "kadikoy_ds_public" {
  count                                          = length(data.aws_availability_zones.available.names)
  vpc_id                                         = aws_vpc.kadikoy.id
  availability_zone                              = data.aws_availability_zones.available.names[count.index]
  cidr_block                                     = cidrsubnet(aws_vpc.kadikoy.cidr_block, 8, (4 * length(data.aws_availability_zones.available.names)) + count.index)
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.kadikoy.ipv6_cidr_block, 8, (4 * length(data.aws_availability_zones.available.names)) + count.index)
  ipv6_native                                    = false
  map_public_ip_on_launch                        = true
  assign_ipv6_address_on_creation                = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_dns64                                   = false
  tags = {
    Name           = format("%s-%s-%s-%s", var.Project, "ds", "public", count.index + 1)
    IPv4           = "false"
    IPv6           = "true"
    IPv6EgressType = "direct"
    IPv4EgressType = "direct"
  }
}


resource "aws_subnet" "kadikoy_ds_private" {
  count                                          = length(data.aws_availability_zones.available.names)
  vpc_id                                         = aws_vpc.kadikoy.id
  availability_zone                              = data.aws_availability_zones.available.names[count.index]
  cidr_block                                     = cidrsubnet(aws_vpc.kadikoy.cidr_block, 8, (5 * length(data.aws_availability_zones.available.names)) + count.index)
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.kadikoy.ipv6_cidr_block, 8, (5 * length(data.aws_availability_zones.available.names)) + count.index)
  ipv6_native                                    = false
  map_public_ip_on_launch                        = false
  assign_ipv6_address_on_creation                = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_dns64                                   = false

  tags = {
    Name       = format("%s-%s-%s-%s", var.Project, "ds", "private", count.index + 1)
    IPv4       = "true"
    IPv6       = "true"
    IPv6Egress = "block"
    IPv4Egress = "block"
    Type       = "private"
  }
}
resource "aws_route_table_association" "kadikoy_ds_private_rtba" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.kadikoy_ds_private[count.index].id
  route_table_id = aws_route_table.kadikoy_private.id
}

data "aws_route_tables" "kadikoy-route-tables" {
  vpc_id = aws_vpc.kadikoy.id
}


// VPC endpoints

// Gateway based
resource "aws_vpc_endpoint" "kadikoy-vpce-s3" {
  vpc_id            = aws_vpc.kadikoy.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  auto_accept       = true
  route_table_ids   = data.aws_route_tables.kadikoy-route-tables.ids
  //private_dns_enabled = true

  tags = {
    Name = "kadikoy-s3"
  }
}


resource "aws_security_group" "kadikoy-internal-only" {
  name        = "allow_internal"
  description = "Allow VPC only internal traffic"
  vpc_id      = aws_vpc.kadikoy.id

  ingress {
    description      = "from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_vpc.kadikoy.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.kadikoy.ipv6_cidr_block]
  }

  egress {
    description      = "to VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_vpc.kadikoy.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.kadikoy.ipv6_cidr_block]
  }

  tags = {
    Name = "kadikoy-sg-internal-only"
  }
}


data "aws_subnets" "kadikoy-subnets" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.kadikoy.id]
  }

  tags = {
    Type = "private"
  }

}

// Interface based
resource "aws_vpc_endpoint" "kadikoy-vpce-ec2" {
  vpc_id            = aws_vpc.kadikoy.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_endpoint_type = "Interface"

  subnet_ids          = data.aws_subnets.kadikoy-subnets.ids
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.kadikoy-internal-only.id]


  tags = {
    Name = "kadikoy-ec2"
  }
}
# resource "aws_vpc_endpoint_subnet_association" "kadikoy-vpce-ec2" {
#   for_each = toset(data.aws_subnets.ozer-subnets.ids)

#   vpc_endpoint_id = aws_vpc_endpoint.ozer-ec2.id
#   subnet_id       = each.value
# }

resource "aws_vpc_endpoint" "kadikoy-ecr-api-vpce" {
  vpc_id            = aws_vpc.kadikoy.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids          = data.aws_subnets.kadikoy-subnets.ids
  private_dns_enabled = true

  security_group_ids = [aws_security_group.kadikoy-internal-only.id]
  tags = {
    Name = "kadikoy-ecr-api"
  }
}
resource "aws_vpc_endpoint" "kadikoy-ecr-dkr-vpce" {
  vpc_id             = aws_vpc.kadikoy.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.kadikoy-internal-only.id]

  subnet_ids          = data.aws_subnets.kadikoy-subnets.ids
  private_dns_enabled = true

  tags = {
    Name = "kadikoy-ecr-dkr"
  }
}

resource "aws_ec2_instance_connect_endpoint" "kadikoy" {
  subnet_id          = aws_subnet.kadikoy_ds_private[0].id
  security_group_ids = [aws_security_group.kadikoy-internal-only.id]

  tags = {
    Name = "kadikoy-ec2-connect"
  }
}

resource "aws_default_security_group" "kadikoy_default_sg" {
  vpc_id = aws_vpc.kadikoy.id

  ingress {
    description      = "from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_vpc.kadikoy.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.kadikoy.ipv6_cidr_block]
  }

  egress {
    description      = "to VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_vpc.kadikoy.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.kadikoy.ipv6_cidr_block]
  }

  tags = {
    Name = "kadikoy-sg-default"
  }
}
