name = "aws-load-balancer-controller"
repository = "https://aws.github.io/eks-charts"
chart = "aws-load-balancer-controller"
namespace = "kube-system"


set {
name = "clusterName"
value = module.eks.cluster_id
}
set {
name = "region"
value = var.region
}
set {
name = "vpcId"
value = module.vpc.vpc_id
}
}