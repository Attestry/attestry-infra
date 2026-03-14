module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "portfolio-eks-vpc"
  cidr = "10.0.0.0/16"

  # 가용 영역 3개 사용 (ap-northeast-2a, 2b, 2c)
  azs              = ["ap-northeast-2a", "ap-northeast-2c", "ap-northeast-2d"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  # NAT Gateway 구성 
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/attestry-dev-cluster" = "shared"
    "kubernetes.io/role/elb"                     = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/attestry-dev-cluster" = "shared"
    "kubernetes.io/role/internal-elb"            = "1"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Project     = "attestry"
  }
}
