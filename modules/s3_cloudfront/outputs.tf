output "s3_website_url" {
  description = "S3 website endpoint for Quantum Judge frontend"
  value       = aws_s3_bucket_website_configuration.frontend_website.website_endpoint
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name for Quantum Judge frontend"
  value       = aws_cloudfront_distribution.frontend_cdn.domain_name
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.frontend_bucket.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend_cdn.id
}

