provider "aws" { }

data "aws_caller_identity" "current" { }

module "vpc" {
  source = "../../common/module-vpc"
  prefix = "${var.prefix}"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  cidr_block = "172.16.0.0/20"
}

resource "aws_vpc_peering_connection" "build" {
  peer_owner_id = "${data.aws_caller_identity.current.id}"
  peer_vpc_id = "${var.build_vpc_id}"
  vpc_id = "${module.vpc.vpc_id}"
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags {
    Name = "${var.prefix}-${var.component}-${var.role_group}-subnet"
    Component = "${var.component}"
    Owner = "${var.owner}"
    RoleGroup = "${var.role_group}"
    Environment = "${var.environment}"
  }
}

module "media" {
  source = "../module-media"
  prefix = "${var.prefix}"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  domain = "media.fm-orbba.com",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.media_instance_type}"
  ami_id = "${var.media_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-media-ubuntu.pub")}"
}

module "signaling" {
  source = "../module-signaling"
  prefix = "${var.prefix}"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  domain = "signaling.fm-orbba.com",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.signaling_instance_type}"
  ami_id = "${var.signaling_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-signaling-ubuntu.pub")}"
}

module "auth" {
  source = "../module-auth"
  prefix = "${var.prefix}"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "build"
  environment = "${var.environment}"
  domain = "auth.fm-orbba.com",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.media_instance_type}"
  ami_id = "${var.auth_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-auth-ubuntu.pub")}"
}

module "recording" {
  source = "../module-recording"
  prefix = "${var.prefix}"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"
  domain = "recording.fm-orbba.com",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.media_instance_type}"
  ami_id = "${var.recording_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-recording-ubuntu.pub")}"
}

module "demo" {
  source = "../module-demo"
  prefix = "${var.prefix}"
  owner = "${var.owner}"
  component = "${var.component}"
  role_group = "${var.role_group}"
  environment = "${var.environment}"

  domain = "demo.fm-orbba.com",
  delegation_set_id = "${var.delegation_set_id}"
  instance_type = "${var.demo_instance_type}"
  ami_id = "${var.demo_ami_id}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.subnet_id}"
  public_key = "${file("keys/webrtc-core-demo-ubuntu.pub")}"
}
