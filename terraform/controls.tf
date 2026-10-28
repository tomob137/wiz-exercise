# =================== PREVENTIVE: account-wide secure defaults ===================

# Every new EBS volume in this region is encrypted, whoever creates it.
resource "aws_ebs_encryption_by_default" "on" {
  enabled = true
}

# Every new EC2 instance defaults to IMDSv2 (token-protected metadata service).
resource "aws_ec2_instance_metadata_defaults" "imdsv2" {
  http_tokens                 = "required"
  http_put_response_hop_limit = 2 # lets containers on the host use IMDSv2 too
}

# (S3 Block Public Access is already on the CloudTrail and Config buckets.
#  The backup bucket is the documented exception the brief requires.)

# =================== DETECTIVE: AWS Config recorder ===================
resource "aws_s3_bucket" "config" {
  bucket        = "${var.name}-config-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = aws_s3_bucket.config.arn
      },
      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.config]
}

resource "aws_iam_role" "config" {
  name = "${var.name}-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name = "deliver-to-config-bucket"
  role = aws_iam_role.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = "${aws_s3_bucket.config.arn}/*" },
      { Effect = "Allow", Action = ["s3:GetBucketAcl"], Resource = aws_s3_bucket.config.arn }
    ]
  })
}

# Record only the two resource types our rules need (cheaper, quieter).
resource "aws_config_configuration_recorder" "main" {
  name     = "default"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported  = false
    resource_types = ["AWS::EC2::SecurityGroup", "AWS::S3::Bucket"]
    recording_strategy {
      use_only = "INCLUSION_BY_RESOURCE_TYPES"
    }
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.config.bucket
  depends_on     = [aws_config_configuration_recorder.main, aws_s3_bucket_policy.config]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# =================== DETECTIVE: AWS Config managed rules ===================
resource "aws_config_config_rule" "restricted_ssh" {
  name = "restricted-ssh"
  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }
  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "s3_public_read" {
  name = "s3-bucket-public-read-prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
  depends_on = [aws_config_configuration_recorder_status.main]
}