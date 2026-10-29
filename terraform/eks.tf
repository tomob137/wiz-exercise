module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.name}-eks"
  kubernetes_version = "1.37"

  # The API endpoint is reachable from the internet (you and GitHub's runners
  # need it); every request still needs AWS IAM authentication.
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = false

  # Auto Mode: AWS manages the nodes and the load balancer controller
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # nodes and pods live ONLY in private subnets

  # Kubernetes control plane audit logging to CloudWatch Logs
  enabled_log_types = ["api", "audit", "authenticator"]

  kms_key_administrators = [
    "arn:aws:iam::949678234896:user/odl_user_2445900",
    aws_iam_role.github_actions.arn,
  ]

  access_entries = {
    lab_admin = {
      principal_arn = "arn:aws:iam::949678234896:user/odl_user_2445900"
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    github_actions = {
      principal_arn = aws_iam_role.github_actions.arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

output "cluster_name" {
  value = module.eks.cluster_name
}