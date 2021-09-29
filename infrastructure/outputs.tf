output "endpoint_url" {
  description = "Application endpoint"
  value       = "https://${var.endpoint_name}.${var.hosted_zone_name}/docs"
}
