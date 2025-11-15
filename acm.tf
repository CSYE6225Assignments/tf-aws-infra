# ==============================================================================
# ACM Certificate Data Source (DEV - imported manually)
# ==============================================================================
data "aws_acm_certificate" "dev_certificate" {
  count       = var.environment == "dev" ? 1 : 0
  domain      = "${var.environment}.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}