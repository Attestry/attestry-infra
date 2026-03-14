# eks.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # 클러스터 이름: 프로젝트 명확화
  cluster_name    = "attestry-dev-cluster"
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  create_kms_key              = false
  cluster_encryption_config   = {}
  create_cloudwatch_log_group = false

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # 노드 그룹 네이밍: 역할 기반 분리
  eks_managed_node_groups = {
    attestry-app-worker = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      disk_size      = 80
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      labels = {
        "node-role" = "application"
        "workload"  = "app-services"
      }

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }

    attestry-kafka-worker = {
      min_size     = 3
      max_size     = 3
      desired_size = 3

      disk_size      = 100
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"

      labels = {
        "node-role" = "stateful"
        "workload"  = "kafka"
      }

      taints = {
        dedicated = {
          key    = "dedicated"
          value  = "kafka"
          effect = "NO_SCHEDULE"
        }
      }

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "dev"
    Project     = "attestry"
    ManagedBy   = "terraform"
  }
}

# output 
output "configure_kubectl" {
  description = "EKS 접속을 위한 설정 명령"
  value       = "aws eks update-kubeconfig --region ap-northeast-2 --name ${module.eks.cluster_name}"
}

# addon 설정 (EBS CSI Driver)
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  # 노드 그룹이 준비된 후 설치되도록 보장
  depends_on = [module.eks.eks_managed_node_groups]
}
