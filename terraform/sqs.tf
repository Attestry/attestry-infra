resource "aws_sqs_queue" "invitation" {
  name                       = "attestry-dev-invitations"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10

  tags = {
    Environment = "dev"
    Project     = "attestry"
    ManagedBy   = "terraform"
  }
}
