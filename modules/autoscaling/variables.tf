variable "namespace" {
  type = string
}

variable "ssh_keypair" {
  type = string
}

variable "sg" {
  type = any
}

variable "vpc" {
  type = any
}

variable "subnet_public" {
  type = list(string)
}

variable "subnet_private" {
  type = list(string)
}

variable "certificate_arn" {
  default = "Enter Your ARN Certificate generated from certificate manager"
}

variable "route53_hosted_zone_name" {
  default = "Enter You Hosted Domain Name from AWS Route53"
}
