variable "vpc_id" {
  description = "VPC where the security group is created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet where the instance is launched"
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH in, e.g. x.x.x.x/32"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "Name tag for the instance"
  type        = string
  default     = "terraform-ec2-instance-demo"
}