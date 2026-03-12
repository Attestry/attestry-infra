# outputs.tf

# 생성된 VPC의 ID를 출력 (EKS 클러스터 생성 시 필요)
output "vpc_id" {
  description = "VPC ID for Attestry Project"
  value       = module.vpc.vpc_id
}

# 프라이빗 서브넷 ID 리스트 (EKS 노드가 배치될 곳)
output "private_subnets" {
  description = "Private Subnets for EKS Nodes"
  value       = module.vpc.private_subnets
}

# 퍼블릭 서브넷 ID 리스트 (ALB/Ingress가 배치될 곳)
output "public_subnets" {
  description = "Public Subnets for Load Balancers"
  value       = module.vpc.public_subnets
}

# 데이터베이스 서브넷 ID 리스트 (RDS Aurora가 배치될 곳)
output "database_subnets" {
  description = "Database Subnets for RDS Aurora"
  value       = module.vpc.database_subnets
}