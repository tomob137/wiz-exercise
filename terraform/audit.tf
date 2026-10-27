data "aws_caller_identity" "current" {}

# ---------- CloudTrail: control plane audit logging ----------
# A private bucket that only CloudTrail can write to.
resource "aws_s3_bucket" "trail" {
  bucket        = "${var.name}-cloudtrail-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.trail]
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.name}-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  is_multi_region_trail         = true # record every region, not just this one
  include_global_service_events = true # include IAM, which is global
  enable_log_file_validation    = true # tamper evidence: signed digest files
  depends_on                    = [aws_s3_bucket_policy.trail]
}

# ---------- GuardDuty: threat detection (detective control) ----------
resource "aws_guardduty_detector" "main" {
  enable = true
}

# Watch the Kubernetes audit log too (catches the cluster-admin binding later).
resource "aws_guardduty_detector_feature" "eks_audit" {
  detector_id = aws_guardduty_detector.main.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.trail.bucket
}