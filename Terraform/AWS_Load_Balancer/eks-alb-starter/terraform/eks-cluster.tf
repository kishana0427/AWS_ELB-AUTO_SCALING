module "eks" {
source = "terraform-aws-modules/eks/aws"
cluster_name = var.cluster_name
cluster_version = var.k8s_version
vpc_id = module.vpc.vpc_id
subnets = module.vpc.public_subnets


node_groups = {
default = {
desired_capacity = 2
max_capacity = 3
min_capacity = 1
instance_types = ["t3.medium"]
}
}
}


# obtain auth token
data "aws_eks_cluster_auth" "cluster" {
name = module.eks.cluster_id
}