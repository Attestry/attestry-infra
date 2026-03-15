locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  invitation_queue_name     = "${local.name_prefix}-invitations${var.invitation_queue_fifo ? ".fifo" : ""}"
  invitation_dlq_name       = "${local.name_prefix}-invitations-dlq${var.invitation_queue_fifo ? ".fifo" : ""}"
  invitation_lambda_name    = "${local.name_prefix}-invitation-email-handler"
  invitation_lambda_log_grp = "/aws/lambda/${local.invitation_lambda_name}"
}

resource "aws_sqs_queue" "invitation_dlq" {
  name                        = local.invitation_dlq_name
  fifo_queue                  = var.invitation_queue_fifo
  content_based_deduplication = var.invitation_queue_fifo ? true : null
  message_retention_seconds   = var.invitation_queue_message_retention_seconds

  tags = local.common_tags
}

resource "aws_sqs_queue" "invitation" {
  name                        = local.invitation_queue_name
  fifo_queue                  = var.invitation_queue_fifo
  content_based_deduplication = var.invitation_queue_fifo ? true : null
  visibility_timeout_seconds  = var.invitation_queue_visibility_timeout_seconds
  message_retention_seconds   = var.invitation_queue_message_retention_seconds
  receive_wait_time_seconds   = var.invitation_queue_receive_wait_time_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.invitation_dlq.arn
    maxReceiveCount     = var.invitation_dlq_max_receive_count
  })

  lifecycle {
    precondition {
      condition     = var.invitation_queue_visibility_timeout_seconds > var.invitation_lambda_timeout_seconds
      error_message = "invitation_queue_visibility_timeout_seconds must be greater than invitation_lambda_timeout_seconds."
    }
  }

  tags = local.common_tags
}

resource "aws_sqs_queue_redrive_allow_policy" "invitation_dlq" {
  queue_url = aws_sqs_queue.invitation_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.invitation.arn]
  })
}

data "archive_file" "invitation_email_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/invitation_email_handler.py"
  output_path = "${path.module}/invitation_email_handler.zip"
}

resource "aws_cloudwatch_log_group" "invitation_email_lambda" {
  name              = local.invitation_lambda_log_grp
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_iam_role" "invitation_email_lambda" {
  name = "${local.invitation_lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "invitation_email_lambda_basic" {
  role       = aws_iam_role.invitation_email_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "invitation_email_lambda_sqs" {
  role       = aws_iam_role.invitation_email_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "invitation_email_lambda_ses" {
  name = "${local.invitation_lambda_name}-ses"
  role = aws_iam_role.invitation_email_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "invitation_email" {
  function_name = local.invitation_lambda_name
  role          = aws_iam_role.invitation_email_lambda.arn
  handler       = "invitation_email_handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.invitation_lambda_timeout_seconds
  memory_size   = var.invitation_lambda_memory_size

  filename         = data.archive_file.invitation_email_lambda.output_path
  source_code_hash = data.archive_file.invitation_email_lambda.output_base64sha256

  environment {
    variables = {
      SES_REGION         = var.aws_region
      FROM_EMAIL_ADDRESS = var.from_email_address
      REPLY_TO_ADDRESS   = var.reply_to_address
      SUBJECT_PREFIX     = var.subject_prefix
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.invitation_email_lambda,
    aws_iam_role_policy_attachment.invitation_email_lambda_basic,
    aws_iam_role_policy_attachment.invitation_email_lambda_sqs,
    aws_iam_role_policy.invitation_email_lambda_ses,
  ]

  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "invitation_email" {
  event_source_arn                   = aws_sqs_queue.invitation.arn
  function_name                      = aws_lambda_function.invitation_email.arn
  batch_size                         = var.invitation_lambda_batch_size
  function_response_types            = ["ReportBatchItemFailures"]
  maximum_batching_window_in_seconds = var.invitation_queue_fifo ? null : 5
  enabled                            = true
}
