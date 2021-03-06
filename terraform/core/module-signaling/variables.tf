/* The application component that this resource is a part of, ie: webrtc.
   This will be included as part of the resource name.
*/
variable component {
  type = "string"
}

/* The owner of the resources, ie: test/prototype.
   This will be included as part of the resource name.
*/
variable owner {
  type = "string"
}

/* The role group that the resource belongs to, ie: build/main.
   This will be included as part of the resource name.
*/
variable role_group {
  type = "string"
}

/* The role label for the node.
*/
variable role {
  type = "string"
  default = "signaling"
}

/* The environment that the media server will be deployed to.
*/
variable environment {
  type = "string"
}

/* The domain name that will be used for routing.
*/
variable domain {
  type = "string"
}

/* The id of the delegation set to use for dns resolution.
*/
variable delegation_set_id {
  type = "string"
}

/* The public key of the root user.
*/
variable public_key {
  type = "string"
}

/* The ID of the AMI to use when launching the EC2 instance.
   This should be overridden by an overrides file that is generated by the provisioning script.
*/
variable ami_id {
  type = "string"
}

/* The type of EC2 instance to launch.
*/
variable instance_type {
  type = "string"
}

/* The id of the VPC to associate with the EC2 instance.
*/
variable vpc_id {
  type = "string"
}

/* The id of the subnet to associate with the EC2 instance.
*/
variable subnet_id {
  type = "string"
}

/* The CIDR blocks that are allowed to access the webmin interface.
*/
variable allowed_webmin_cidr_blocks {
  type = "list"
}

/* The CIDR blocks that are allowed to connect via SSH.
*/
variable allowed_ssh_cidr_blocks {
  type = "list"
}
