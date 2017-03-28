resource "aws_security_group" "default" {
  name = "${var.component}-${var.role_group}-${var.role}-security_group"
  description = "Security group for the teamcity server."
  vpc_id = "${var.vpc_id}"

  ingress {
    protocol = "tcp"
    from_port = "${var.teamcity_port}"
    to_port = "${var.teamcity_port}"
    cidr_blocks = "${var.teamcity_allowed_cidr_blocks}"
  }

  ingress {
    protocol = "tcp"
    from_port = 49152
    to_port = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "tcp"
    from_port = 0
    to_port = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.component}-${var.role_group}-${var.role}-security_group"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Role = "${var.role}"
  }
}

resource "aws_key_pair" "default" {
  key_name = "${var.component}-${var.role_group}-${var.role}-key_pair"
  public_key = "${var.public_key}"
}

resource "aws_instance" "default" {
  ami = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  key_name = "${aws_key_pair.default.key_name}"
  subnet_id = "${var.subnet_id}"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  tags {
    Name = "${var.component}-${var.role_group}-${var.role}-instance"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Role = "${var.role}"
  }
}

resource "aws_route53_zone" "default" {
  name = "${var.domain}"
  delegation_set_id = "${var.delegation_set_id}"

  tags {
    Name = "${var.component}-${var.role_group}-${var.role}-route53_zone"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Role = "${var.role}"
  }
}

resource "aws_route53_record" "a" {
  zone_id = "${aws_route53_zone.default.zone_id}"
  name = "${var.domain}"
  type = "A"
  ttl = "60"
  records = ["${aws_instance.default.public_ip}"]
}
