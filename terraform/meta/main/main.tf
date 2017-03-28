provider "aws" {
  region = "us-west-1"
}

module "vpc" {
  source = "../../common/module-vpc"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  cidr_block = "10.0.0.0/24"
}

module "teamcity" {
  source = "../module-teamcity"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  domain = "${var.domain}",
  delegation_set_id = "${var.delegation_set_id}"
  ami_id = "${var.teamcity_ami_id}"
  instance_type = "${var.instance_type}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-meta-teamcity-ubuntu.pub")}"
  teamcity_port = 8111
  teamcity_allowed_cidr_blocks = ["74.121.33.9/32"]
}
