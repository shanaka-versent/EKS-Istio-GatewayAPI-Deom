# MTKC POC EKS - Static Assets S3 Bucket Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.static_assets.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.static_assets.arn
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name (for CloudFront origin)"
  value       = aws_s3_bucket.static_assets.bucket_regional_domain_name
}

output "bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.static_assets.bucket_domain_name
}

output "sample_assets_paths" {
  description = "Paths to sample static assets"
  value = {
    css   = "/static/css/styles.css"
    js    = "/static/js/app.js"
    logo  = "/static/images/logo.svg"
  }
}
