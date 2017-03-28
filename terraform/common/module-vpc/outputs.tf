/* The id of the new VPC.
*/
output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

/* The subnet id of the VPC's subnet.
*/
output "subnet_id" {
  value = "${aws_subnet.main.id}"
}

/* The id of the VPC's internet gateway.
*/
output "internet_gateway_id" {
  value = "${aws_internet_gateway.main.id}"
}
