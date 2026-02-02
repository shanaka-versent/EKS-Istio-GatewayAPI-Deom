# MTKC POC EKS - Static Assets S3 Bucket
# @author Shanaka Jayasundera - shanakaj@gmail.com
#
# LAYER 2: Base EKS Cluster Setup (Terraform)
# This module creates an S3 bucket for static assets (CSS, JS, images)
# that will be served via CloudFront.

# Random suffix for bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket for static assets
resource "aws_s3_bucket" "static_assets" {
  bucket        = "${var.name_prefix}-static-assets-${random_id.bucket_suffix.hex}"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name   = "${var.name_prefix}-static-assets"
    Layer  = "Layer2-Infrastructure"
    Module = "static-assets"
  })
}

# Block all public access - CloudFront will use OAC
resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for asset management
resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CORS configuration for static assets
resource "aws_s3_bucket_cors_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# Lifecycle policy for old versions
resource "aws_s3_bucket_lifecycle_configuration" "static_assets" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.static_assets.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# NOTE: Bucket policy for CloudFront OAC is added in main.tf
# after CloudFront distribution is created to avoid circular dependency

# Upload sample static assets
resource "aws_s3_object" "static_css" {
  count        = var.upload_sample_assets ? 1 : 0
  bucket       = aws_s3_bucket.static_assets.id
  key          = "static/css/styles.css"
  content      = <<-EOF
/* MTKC POC - Sample Static CSS */
/* Served from S3 via CloudFront */

:root {
  --primary-color: #3498db;
  --secondary-color: #2ecc71;
  --background-color: #f5f5f5;
  --text-color: #333;
  --border-radius: 8px;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  background-color: var(--background-color);
  color: var(--text-color);
  line-height: 1.6;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
  color: white;
  padding: 40px 20px;
  text-align: center;
  border-radius: var(--border-radius);
  margin-bottom: 20px;
}

.header h1 {
  font-size: 2.5rem;
  margin-bottom: 10px;
}

.header p {
  font-size: 1.2rem;
  opacity: 0.9;
}

.card {
  background: white;
  border-radius: var(--border-radius);
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
  padding: 20px;
  margin-bottom: 20px;
}

.card h2 {
  color: var(--primary-color);
  margin-bottom: 15px;
  border-bottom: 2px solid var(--primary-color);
  padding-bottom: 10px;
}

.status-badge {
  display: inline-block;
  padding: 5px 15px;
  border-radius: 20px;
  font-size: 0.9rem;
  font-weight: bold;
}

.status-healthy {
  background-color: #d4edda;
  color: #155724;
}

.status-warning {
  background-color: #fff3cd;
  color: #856404;
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-top: 20px;
}

.info-item {
  background: #f8f9fa;
  padding: 15px;
  border-radius: var(--border-radius);
  border-left: 4px solid var(--primary-color);
}

.info-item strong {
  display: block;
  color: var(--primary-color);
  margin-bottom: 5px;
}

.footer {
  text-align: center;
  padding: 20px;
  color: #666;
  font-size: 0.9rem;
}
EOF
  content_type = "text/css"
  etag         = md5(<<-EOF
/* MTKC POC - Sample Static CSS */
/* Served from S3 via CloudFront */

:root {
  --primary-color: #3498db;
  --secondary-color: #2ecc71;
  --background-color: #f5f5f5;
  --text-color: #333;
  --border-radius: 8px;
}
EOF
  )

  tags = merge(var.tags, {
    Name = "sample-css"
  })
}

resource "aws_s3_object" "static_js" {
  count        = var.upload_sample_assets ? 1 : 0
  bucket       = aws_s3_bucket.static_assets.id
  key          = "static/js/app.js"
  content      = <<-EOF
// MTKC POC - Sample Static JavaScript
// Served from S3 via CloudFront

(function() {
  'use strict';

  // Application configuration
  const config = {
    appName: 'MTKC POC Demo',
    version: '1.0.0',
    staticAssetsSource: 'S3 + CloudFront'
  };

  // Initialize app when DOM is ready
  document.addEventListener('DOMContentLoaded', function() {
    console.log('%c' + config.appName + ' v' + config.version, 'color: #3498db; font-size: 16px; font-weight: bold;');
    console.log('Static assets served from: ' + config.staticAssetsSource);

    initializeApp();
  });

  function initializeApp() {
    // Add loading indicator
    addLoadingIndicator();

    // Fetch and display server info
    displayStaticAssetInfo();

    // Add timestamp
    addTimestamp();
  }

  function addLoadingIndicator() {
    const indicator = document.createElement('div');
    indicator.className = 'static-asset-indicator';
    indicator.innerHTML = '<span class="status-badge status-healthy">JS Loaded from CloudFront</span>';

    const container = document.querySelector('.container');
    if (container) {
      container.insertBefore(indicator, container.firstChild);
    }
  }

  function displayStaticAssetInfo() {
    const infoDiv = document.getElementById('static-info');
    if (infoDiv) {
      infoDiv.innerHTML = `
        <div class="info-item">
          <strong>Static Assets</strong>
          Source: S3 + CloudFront CDN
        </div>
        <div class="info-item">
          <strong>Cache Status</strong>
          Edge-cached globally
        </div>
        <div class="info-item">
          <strong>App Version</strong>
          $${config.version}
        </div>
      `;
    }
  }

  function addTimestamp() {
    const timestampDiv = document.getElementById('load-timestamp');
    if (timestampDiv) {
      timestampDiv.textContent = 'Page loaded: ' + new Date().toISOString();
    }
  }

  // Export for debugging
  window.MTKCApp = {
    config: config,
    version: config.version
  };
})();
EOF
  content_type = "application/javascript"

  tags = merge(var.tags, {
    Name = "sample-js"
  })
}

# Sample SVG logo
resource "aws_s3_object" "static_logo" {
  count        = var.upload_sample_assets ? 1 : 0
  bucket       = aws_s3_bucket.static_assets.id
  key          = "static/images/logo.svg"
  content      = <<-EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 60">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#3498db;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#2ecc71;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect x="5" y="5" width="50" height="50" rx="10" fill="url(#grad)"/>
  <text x="70" y="38" font-family="Arial, sans-serif" font-size="24" font-weight="bold" fill="#333">MTKC POC</text>
  <text x="70" y="52" font-family="Arial, sans-serif" font-size="10" fill="#666">EKS + Istio + Gateway API</text>
</svg>
EOF
  content_type = "image/svg+xml"

  tags = merge(var.tags, {
    Name = "sample-logo"
  })
}
