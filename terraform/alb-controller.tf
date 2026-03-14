# alb-controller.tf

# AWS Load Balancer Controller IAM Policy
data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.http.alb_controller_policy.response_body
}

# IRSA - Service Account용 IAM Role
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "attestry-alb-controller"

  role_policy_arns = {
    policy = aws_iam_policy.alb_controller.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Environment = "dev"
    Project     = "attestry"
    ManagedBy   = "terraform"
  }
}

output "alb_controller_role_arn" {
  description = "ALB Controller IRSA Role ARN"
  value       = module.alb_controller_irsa.iam_role_arn
}
