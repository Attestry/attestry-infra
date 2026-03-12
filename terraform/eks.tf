# eks.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "attestry-eks-cluster"
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  create_kms_key              = false
  cluster_encryption_config   = {}     # 전용 암호화 설정을 비웁니다.
  create_cloudwatch_log_group = false  # 전용 로그 그룹을 만들지 않습니다.

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    standard = {
      min_size     = 3
      max_size     = 5
      desired_size = 3

      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "dev"
    Project     = "attestry"
  }
}

# output 
output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ap-northeast-2 --name ${module.eks.cluster_name}"
}

# addon 설정
resource "aws_eks_addon" "ebs_csi" {

  cluster_name = module.eks.cluster_name 
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [module.eks.eks_managed_node_groups]
}