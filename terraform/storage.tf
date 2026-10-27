# ---------- Backup bucket: public read + public list (INTENTIONAL WEAKNESS) ----------
resource "aws_s3_bucket" "backups" {
  bucket        = "${var.name}-mongo-backups-${random_id.suffix.hex}"
  force_destroy = true
}

# New buckets block public access by default. Turn that off for THIS bucket only.
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "backups_public" {
  bucket = aws_s3_bucket.backups.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicList" # anyone can list the files
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:ListBucket"
        Resource  = aws_s3_bucket.backups.arn
      },
      {
        Sid       = "PublicRead" # anyone can download any file
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.backups.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.backups]
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}