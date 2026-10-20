variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "key_name" {
  type = string
}

variable "ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}