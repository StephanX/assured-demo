resource "aws_route53_zone" "root" {
  name = var.root_domain
}

output "route53_zone_name_servers" {
  description = "Name servers of Route53 zone"
  value       = [for v in aws_route53_zone.root.name_servers: v]
}
