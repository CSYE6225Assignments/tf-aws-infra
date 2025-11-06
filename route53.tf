# ==============================================================================
# ROUTE53 DATA SOURCE - EXISTING HOSTED ZONE
# ==============================================================================
data "aws_route53_zone" "domain" {
  name         = "${var.environment}.${var.domain_name}"  # Will be demo.dhruvbaraiya.me
  private_zone = false
}

# ==============================================================================
# ROUTE53 A RECORD - POINTS TO APPLICATION LOAD BALANCER
# ==============================================================================
resource "aws_route53_record" "application" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "${var.environment}.${var.domain_name}"  # Will be demo.dhruvbaraiya.me
  type    = "A"

  alias {
    name                   = aws_lb.application.dns_name
    zone_id                = aws_lb.application.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.application]
}