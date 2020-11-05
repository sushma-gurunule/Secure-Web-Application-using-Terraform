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
  default = "arn:aws:acm:us-east-1:129632609039:certificate/e7cbbf0d-0bb5-45c9-abde-18381a757296"
}

variable "route53_hosted_zone_name" {
  default = "cmcloudlab881.info"
}
