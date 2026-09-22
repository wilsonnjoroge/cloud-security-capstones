output "public_alb_id" {
  description = "Public ALB ID."
  value       = aws_lb.public.id
}

output "public_alb_arn" {
  description = "Public ALB ARN."
  value       = aws_lb.public.arn
}

output "public_alb_dns_name" {
  description = "Public ALB DNS name."
  value       = aws_lb.public.dns_name
}

output "internal_alb_id" {
  description = "Internal ALB ID."
  value       = aws_lb.internal.id
}

output "internal_alb_arn" {
  description = "Internal ALB ARN."
  value       = aws_lb.internal.arn
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS name."
  value       = aws_lb.internal.dns_name
}

output "web_target_group_arn" {
  description = "Web target group ARN."
  value       = aws_lb_target_group.web.arn
}

output "app_target_group_arn" {
  description = "App target group ARN."
  value       = aws_lb_target_group.app.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "waf_web_acl_arn" {
  description = "CloudFront WAF Web ACL ARN."
  value       = aws_wafv2_web_acl.this.arn
}
