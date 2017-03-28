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

/* The environment of the resource, if applicable.
*/
variable environment {
  type = "string"
  default = "none"
}

/* The CIDR block to configure the VPC with, such as 10.0.0.0/24.
*/
variable cidr_block {
  type = "string"
}
