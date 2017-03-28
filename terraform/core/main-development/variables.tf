/* The application component that this resource is a part of, ie: webrtc.
   This will be included as part of the resource name.
*/
variable component {
  type = "string"
}

/* The owner of the resources, ie: fm/bluefletch.
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

/* The environment that the media server will be deployed to.
*/
variable environment {
  type = "string"
}

/* The main domain name.
*/
variable domain {
  type = "string"
}

/* The CIDR block for the environment's VPC.
*/
variable vpc_cidr_block {
  type = "string"
}

/* The id of the delegation set to use for dns resolution.
*/
variable delegation_set_id {
  type = "string"
}

/* The id of the meta role group's VPC, used for VPC peering.
*/
variable meta_vpc_id {
  type = "string"
}

/* The type of instance to use when launching media servers.
*/
variable "media_instance_type" {
  type = "string"
}

/* The type of instance to use when launching signaling servers.
*/
variable "signaling_instance_type" {
  type = "string"
}

/* The type of instance to use when launching auth servers.
*/
variable "auth_instance_type" {
  type = "string"
}

/* The type of instance to use when launching recording servers.
*/
variable "recording_instance_type" {
  type = "string"
}

/* The type of instance to use when launching demo servers.
*/
variable "demo_instance_type" {
  type = "string"
}
