data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.name}-vpc"
  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]   # load balancer, Mongo VM
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"] # Kubernetes nodes and pods

  enable_nat_gateway   = true
  single_nat_gateway   = true # one NAT is enough for a lab; production would use one per zone
  enable_dns_hostnames = true

  # Tags EKS looks for to know where to put load balancers
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

output "private_subnet_cidrs" {
  value = module.vpc.private_subnets_cidr_blocks
}