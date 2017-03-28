resource "aws_vpc" "main" {
  cidr_block = "${var.cidr_block}"
  enable_dns_hostnames = true

  tags {
    Name = "${var.component}-${var.role_group}-vpc"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "main" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.cidr_block}"

  tags {
    Name = "${var.component}-${var.role_group}-subnet"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Environment = "${var.environment}"
  }
}

resource "aws_default_network_acl" "default" {
  default_network_acl_id = "${aws_vpc.main.default_network_acl_id}"

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags {
    Name = "${var.component}-${var.role_group}-acl"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Environment = "${var.environment}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.component}-${var.role_group}-internet_gateway"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Environment = "${var.environment}"
  }
}

resource "aws_route" "main" {
  route_table_id = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.main.id}"
}
