resource "aws_key_pair" "mykeypair" {
  key_name   = "mykeypair"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
  lifecycle {
    ignore_changes = [public_key]
  }
}

module "autoscaling" {
  source                = "./modules/autoscaling"
  namespace             = var.namespace
  ssh_keypair           = aws_key_pair.mykeypair.key_name
 
  vpc                   = module.networking.vpc
  subnet_public         = tolist(module.networking.subnet-pub)
  subnet_private        = tolist(module.networking.subnet-pri)
  sg                    = module.networking.sg
}
 
module "networking" {
  source    = "./modules/networking"
}

