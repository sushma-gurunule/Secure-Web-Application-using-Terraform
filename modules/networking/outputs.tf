output "vpc" {
  value = "${aws_vpc.web-vpc}"
}

output "subnet-pub" {
  value = "${data.aws_subnet_ids.public.ids}"
}

output "subnet-pri" {
  value = "${data.aws_subnet_ids.private.ids}"
}

output "sg" {
  value = {
    lb     = "${aws_security_group.alb_sg.id}"
    websvr = "${aws_security_group.web_sg.id}"
  }
}
