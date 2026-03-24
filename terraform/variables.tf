variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for the infrastructure."
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "attestry"
}

variable "from_email_address" {
  description = "Verified SES sender email address for invitation emails."
  type        = string
}

variable "reply_to_address" {
  description = "Optional reply-to address for invitation emails."
  type        = string
  default     = ""
}

variable "subject_prefix" {
  description = "Optional subject prefix prepended to invitation email subjects."
  type        = string
  default     = ""
}

variable "invitation_lambda_timeout_seconds" {
  description = "Lambda timeout in seconds for invitation email processing."
  type        = number
  default     = 30
}

variable "invitation_lambda_memory_size" {
  description = "Memory size in MB for the invitation email Lambda."
  type        = number
  default     = 256
}

variable "invitation_queue_visibility_timeout_seconds" {
  description = "Visibility timeout for the invitation source queue. Must exceed the Lambda timeout."
  type        = number
  default     = 90
}

variable "invitation_queue_receive_wait_time_seconds" {
  description = "Long polling wait time for the invitation source queue."
  type        = number
  default     = 10
}

variable "invitation_queue_message_retention_seconds" {
  description = "Message retention period for the invitation queues."
  type        = number
  default     = 345600
}

variable "invitation_dlq_max_receive_count" {
  description = "How many times Lambda may retry a failed invitation message before SQS moves it to the DLQ."
  type        = number
  default     = 5
}

variable "invitation_queue_fifo" {
  description = "Whether the invitation queue should be created as FIFO."
  type        = bool
  default     = false
}

variable "invitation_lambda_batch_size" {
  description = "Number of SQS records delivered to the Lambda in one batch."
  type        = number
  default     = 10
}

variable "notification_dedupe_ttl_seconds" {
  description = "TTL in seconds for notification deduplication records in DynamoDB."
  type        = number
  default     = 86400
}
