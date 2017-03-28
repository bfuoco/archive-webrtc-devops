resource "aws_security_group" "default" {
  name = "${var.component}-${var.role_group}-${var.role}-${var.environment}-security_group"
  description = "Security group for the media server (${var.environment})."
  vpc_id = "${var.vpc_id}"

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = "${var.allowed_ssh_cidr_blocks}"
  }

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 10000
    to_port = 10000
    cidr_blocks = "${var.allowed_webmin_cidr_blocks}"
  }

  ingress {
    protocol = "tcp"
    from_port = 32768
    to_port = 61000
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "udp"
    from_port = 32768
    to_port = 61000
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "tcp"
    from_port = 0
    to_port = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "udp"
    from_port = 0
    to_port = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.component}-${var.role_group}-${var.role}-${var.environment}-security_group"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Role = "${var.role}"
    Environment = "${var.environment}"
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
    Name = "${var.component}-${var.role_group}-${var.role}-${var.environment}-instance"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Role = "${var.role}"
    Environment = "${var.environment}"
  }
}

resource "aws_route53_zone" "default" {
  name = "${var.domain}"
  delegation_set_id = "${var.delegation_set_id}"

  tags {
    Name = "${var.component}-${var.role_group}-${var.role}-${var.environment}-hosted_zone"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Role = "${var.role}"
    Environment = "${var.environment}"
  }
}

resource "aws_route53_record" "a" {
  zone_id = "${aws_route53_zone.default.zone_id}"
  name = "${var.domain}"
  type = "A"
  ttl = "60"
  records = ["${aws_instance.default.public_ip}"]
}
