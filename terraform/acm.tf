# acm.tf – ACM certificate for proveny.live (DNS validation via Cloudflare)

resource "aws_acm_certificate" "proveny" {
  domain_name               = "proveny.live"
  subject_alternative_names = ["*.proveny.live"]
  validation_method         = "DNS"

  tags = {
    Name        = "${var.project_name}-${var.environment}-cert"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}
