provider "aws" { }

data "aws_caller_identity" "current" { }

module "vpc" {
  source = "../../common/module-vpc"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  cidr_block = "${var.vpc_cidr_block}"
}

resource "aws_vpc_peering_connection" "meta" {
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  peer_vpc_id = "${var.meta_vpc_id}"
  vpc_id = "${module.vpc.vpc_id}"
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags {
    Name = "${var.component}-${var.role_group}-${var.environment}-subnet"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Environment = "${var.environment}"
  }
}

module "media" {
  source = "../module-media"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  domain = "media.${var.environment}.${var.domain}",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.media_instance_type}"
  ami_id = "${var.media_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-media-ubuntu.pub")}"
  allowed_webmin_cidr_blocks = ["74.121.33.9/32"]
  allowed_ssh_cidr_blocks = ["74.121.33.9/32"]
}

module "signaling" {
  source = "../module-signaling"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  domain = "signaling.${var.environment}.${var.domain}",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.signaling_instance_type}"
  ami_id = "${var.signaling_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-signaling-ubuntu.pub")}"
  allowed_webmin_cidr_blocks = ["74.121.33.9/32"]
  allowed_ssh_cidr_blocks = ["74.121.33.9/32"]
}

module "auth" {
  source = "../module-auth"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  domain = "auth.${var.environment}.${var.domain}",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.media_instance_type}"
  ami_id = "${var.auth_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-auth-ubuntu.pub")}"
  allowed_webmin_cidr_blocks = ["74.121.33.9/32"]
  allowed_ssh_cidr_blocks = ["74.121.33.9/32"]
}

module "recording" {
  source = "../module-recording"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  domain = "recording.${var.environment}.${var.domain}",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.media_instance_type}"
  ami_id = "${var.recording_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-recording-ubuntu.pub")}"
  allowed_webmin_cidr_blocks = ["74.121.33.9/32"]
  allowed_ssh_cidr_blocks = ["74.121.33.9/32"]
}

module "demo" {
  source = "../module-demo"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  domain = "demo.${var.environment}.${var.domain}",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.demo_instance_type}"
  ami_id = "${var.demo_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-demo-ubuntu.pub")}"
  allowed_webmin_cidr_blocks = ["74.121.33.9/32"]
  allowed_ssh_cidr_blocks = ["74.121.33.9/32"]
}
