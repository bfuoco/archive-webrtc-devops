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

/* The domain to assign to the server.
*/
variable domain {
  type = "string"
}

/* The id of the delegation set to use for dns resolution.
*/
variable delegation_set_id {
  type = "string"
}

/* The type of instance to launch.
*/
variable "instance_type" {
  type = "string"
}
