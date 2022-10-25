resource "random_pet" "this" {
  length = 2
}

resource "aws_s3_object" "hr_data" {
  bucket                 = module.s3_bucket.s3_bucket_id
  key                    = "sourcedata/hr/employee/LOAD0001.csv"
  source                 = "data/hr.csv"
  etag                   = filemd5("data/hr.csv")
  server_side_encryption = "AES256"

  tags = local.tags
}

# A role to allow DMS to access bucket
resource "aws_iam_role" "s3_role" {
  name        = "${local.name}-s3"
  description = "Role used to migrate data from S3 via DMS"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DMSAssume"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.${data.aws_partition.current.dns_suffix}"
        }
      },
    ]
  })

  inline_policy {
    name = "${local.name}-s3"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "DMSRead"
          Action   = ["s3:GetObject"]
          Effect   = "Allow"
          Resource = "${module.s3_bucket.s3_bucket_arn}/*"
        },
        {
          Sid      = "DMSList"
          Action   = ["s3:ListBucket"]
          Effect   = "Allow"
          Resource = module.s3_bucket.s3_bucket_arn
        },
      ]
    })
  }

  tags = local.tags
}
