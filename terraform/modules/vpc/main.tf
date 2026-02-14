locals {
  public_subnets = {
    for idx, cidr in var.public_subnets :
    var.availability_zones[idx] => cidr
  }
  private_subnets = {
    for idx, cidr in var.private_subnets :
    var.availability_zones[idx] => cidr
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}


resource "aws_subnet" "public_subnet" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags = {
    Name                     = "${var.project_name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_subnet" {
  for_each          = local.private_subnets
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Name                              = "${var.project_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_eip" "nat_eip" {
  for_each = local.public_subnets
  domain   = "vpc"
  tags = {
    Name = "${var.project_name}-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  for_each = local.public_subnets
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = aws_subnet.public_subnet[each.key].id # references public subnet by AZ
  tags = {
    Name = "${var.project_name}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.internet_gw]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public_rt.id
  gateway_id             = aws_internet_gateway.internet_gw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_rt_assoc" {
  for_each = local.public_subnets
  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  for_each = local.private_subnets
  vpc_id   = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-private-rt-${each.key}"
  }
}

resource "aws_route" "private_nat_route" {
  for_each               = local.private_subnets
  route_table_id         = aws_route_table.private_rt[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[each.key].id
}

resource "aws_route_table_association" "private_rt_assoc" {
  for_each = local.private_subnets
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.private_rt[each.key].id
}


