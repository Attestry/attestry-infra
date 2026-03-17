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

output "invitation_sqs_queue_name" {
  description = "Invitation SQS queue name"
  value       = aws_sqs_queue.invitation.name
}

output "invitation_sqs_queue_url" {
  description = "Invitation SQS queue URL"
  value       = aws_sqs_queue.invitation.url
}

output "invitation_sqs_dlq_name" {
  description = "Invitation SQS DLQ name"
  value       = aws_sqs_queue.invitation_dlq.name
}

output "invitation_sqs_dlq_url" {
  description = "Invitation SQS DLQ URL"
  value       = aws_sqs_queue.invitation_dlq.url
}

output "invitation_email_lambda_name" {
  description = "Invitation email Lambda function name"
  value       = aws_lambda_function.invitation_email.function_name
}

output "invitation_email_lambda_log_group_name" {
  description = "CloudWatch Logs group for the invitation email Lambda"
  value       = aws_cloudwatch_log_group.invitation_email_lambda.name
}

output "assets_bucket_name" {
  description = "Assets S3 bucket name"
  value       = aws_s3_bucket.assets.bucket
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
}

output "rds_db_name" {
  description = "RDS PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_db_username" {
  description = "RDS PostgreSQL master username"
  value       = aws_db_instance.postgres.username
}

output "rds_master_password" {
  description = "RDS PostgreSQL master password"
  value       = random_password.rds_master.result
  sensitive   = true
}

output "rds_jdbc_url" {
  description = "RDS PostgreSQL JDBC URL"
  value       = "jdbc:postgresql://${aws_db_instance.postgres.address}:5432/${aws_db_instance.postgres.db_name}"
}

output "signup_verification_sqs_queue_url" {
  description = "Signup email verification SQS queue URL"
  value       = aws_sqs_queue.signup_verification.url
}

output "signup_verification_sqs_dlq_url" {
  description = "Signup email verification SQS DLQ URL"
  value       = aws_sqs_queue.signup_verification_dlq.url
}

output "passport_manual_sqs_queue_url" {
  description = "Passport manual notification SQS queue URL"
  value       = aws_sqs_queue.passport_manual.url
}

output "passport_manual_sqs_dlq_url" {
  description = "Passport manual notification SQS DLQ URL"
  value       = aws_sqs_queue.passport_manual_dlq.url
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN for proveny.live"
  value       = aws_acm_certificate.proveny.arn
}

output "acm_dns_validation_records" {
  description = "DNS validation CNAME records — add these in Cloudflare"
  value = {
    for dvo in aws_acm_certificate.proveny.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}
