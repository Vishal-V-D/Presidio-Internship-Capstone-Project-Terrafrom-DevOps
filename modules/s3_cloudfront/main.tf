resource "aws_s3_bucket" "frontend_bucket" {
  bucket = var.bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "frontend_ownership" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend_public_access]
}

resource "aws_cloudfront_distribution" "frontend_cdn" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend_website.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.frontend_bucket.bucket}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend_bucket.bucket}"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = var.tags
}

# ============================================
# AUTOMATIC FRONTEND DEPLOYMENT
# ============================================
# Automatically syncs frontend files to S3 and invalidates CloudFront cache
# Triggers when frontend_source_dir files change

resource "null_resource" "frontend_deploy" {
  # Only deploy if frontend_source_dir is provided
  count = var.frontend_source_dir != null ? 1 : 0

  # Trigger on file changes in frontend directory
  triggers = {
    # This will trigger when you run terraform apply
    # To force re-deploy, change this value manually
    deployment_id = var.force_deploy ? timestamp() : "initial"
    source_dir    = var.frontend_source_dir
  }

  # Upload files to S3 and invalidate CloudFront
  provisioner "local-exec" {
    command = <<-EOT
      echo "Deploying frontend to S3..."
      
      # Sync files to S3
      aws s3 sync "${var.frontend_source_dir}" "s3://${aws_s3_bucket.frontend_bucket.bucket}" --delete
      
      # Create CloudFront invalidation
      echo "Creating CloudFront invalidation..."
      aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend_cdn.id} --paths "/*"
      
      echo "Frontend deployment complete!"
      echo "S3 URL: http://${aws_s3_bucket_website_configuration.frontend_website.website_endpoint}"
      echo "CloudFront URL: https://${aws_cloudfront_distribution.frontend_cdn.domain_name}"
    EOT
  }

  depends_on = [
    aws_s3_bucket.frontend_bucket,
    aws_s3_bucket_policy.frontend_policy,
    aws_cloudfront_distribution.frontend_cdn
  ]
}

# Output deployment status
output "last_deployment" {
  description = "Last frontend deployment timestamp"
  value       = var.frontend_source_dir != null ? (var.force_deploy ? timestamp() : "Not deployed yet - set force_deploy=true") : "Auto-deployment disabled"
}