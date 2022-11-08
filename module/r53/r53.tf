## Request Certificate
resource "aws_acm_certificate" "ideamics_crt" {
  domain_name       = "ideamics.com"
  validation_method = "DNS"
}

## Get Route 53 zone details
data "aws_route53_zone" "ideamics_r53z" {
  name         = "ideamics.com"
  private_zone = false
}

## Create record in hosted zone 
resource "aws_route53_record" "ideamics_record" {
  for_each = {
    for dvo in aws_acm_certificate.ideamics_crt.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.ideamics_r53z.zone_id
}

resource "aws_acm_certificate_validation" "ideamics_validation" {
  certificate_arn         = aws_acm_certificate.ideamics_crt.arn
  validation_record_fqdns = [for record in aws_route53_record.ideamics_record : record.fqdn]
}

# Create new listner to the target group with certificate link
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = var.ecs_lb
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.ideamics_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = var.target_group_arn
  }
}