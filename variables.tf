variable "region" {
  default = "eu-north-1"
  type    = string
}

variable "instance_type" {
  default = "t3.micro"
  type    = string
}

variable "allow_ports" {
  description = "Ports list top open for server"
  type        = list(any)
  default     = ["80", "443", "8080"]
}

variable "vpc_cidr_block" {
  type    = string
  default = "192.168.0.0/16"
}

variable "subnet_a_cidr_block" {
  type    = string
  default = "192.168.101.0/24"
}

variable "subnet_b_cidr_block" {
  type    = string
  default = "192.168.102.0/24"
}
