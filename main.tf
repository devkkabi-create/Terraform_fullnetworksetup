provider "aws" {
  region = var.region
}

module "network" {
  source      = "./modules/network"
  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.subnet_cidr
  vpc_name    = var.vpc_name
}

module "compute" {
  source           = "./modules/compute"
  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.subnet_id
  key_name         = var.key_name
  allowed_ssh_cidr = var.allowed_ssh_cidr
  instance_type    = var.instance_type
}