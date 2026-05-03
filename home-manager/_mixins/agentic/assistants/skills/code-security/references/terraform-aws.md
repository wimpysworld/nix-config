---
title: Secure AWS Terraform Configurations
impact: HIGH
impactDescription: Cloud misconfigurations and data exposure
tags: security, terraform, aws, infrastructure, iac, s3, iam, ec2
---

## Secure AWS Terraform Configurations

Security best practices for AWS Terraform configurations to prevent common misconfigurations.

### S3 Encryption

**Incorrect:**
```hcl
resource "aws_s3_bucket_object" "fail" {
  bucket  = aws_s3_bucket.bucket.bucket
  key     = "my-object"
  content = "data"
}
```

**Correct:**
```hcl
resource "aws_s3_bucket_object" "pass" {
  bucket     = aws_s3_bucket.bucket.bucket
  key        = "my-object"
  content    = "data"
  kms_key_id = aws_kms_key.example.arn
}
```

### IAM Overly Permissive Policies

**Incorrect (wildcard admin):**
```hcl
resource "aws_iam_policy" "fail" {
  policy = <<POLICY
{"Version":"2012-10-17","Statement":[{"Action":"*","Effect":"Allow","Resource":"*"}]}
POLICY
}
```

**Correct (least privilege):**
```hcl
resource "aws_iam_policy" "pass" {
  policy = <<POLICY
{"Version":"2012-10-17","Statement":[{"Action":["s3:GetObject*"],"Effect":"Allow","Resource":"arn:aws:s3:::bucket/*"}]}
POLICY
}
```

**Incorrect (wildcard AssumeRole):**
```hcl
resource "aws_iam_role" "fail" {
  assume_role_policy = <<POLICY
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"*"},"Action":"sts:AssumeRole"}]}
POLICY
}
```

**Correct (restricted AssumeRole):**
```hcl
resource "aws_iam_role" "pass" {
  assume_role_policy = <<POLICY
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::123456789012:root"},"Action":"sts:AssumeRole"}]}
POLICY
}
```

### Unencrypted Storage

**Incorrect (EBS):**
```hcl
resource "aws_ebs_volume" "fail" {
  availability_zone = "us-west-2a"
  encrypted         = false
}
```

**Correct (EBS):**
```hcl
resource "aws_ebs_volume" "pass" {
  availability_zone = "us-west-2a"
  encrypted         = true
}
```

**Incorrect (RDS no backup):**
```hcl
resource "aws_db_instance" "fail" { backup_retention_period = 0 }
```

**Correct (RDS with backup):**
```hcl
resource "aws_db_instance" "pass" { backup_retention_period = 35 }
```

**Incorrect (DynamoDB):**
```hcl
resource "aws_dynamodb_table" "fail" {
  name = "Table"; hash_key = "Id"
  attribute { name = "Id"; type = "S" }
}
```

**Correct (DynamoDB with CMK):**
```hcl
resource "aws_dynamodb_table" "pass" {
  name = "Table"; hash_key = "Id"
  attribute { name = "Id"; type = "S" }
  server_side_encryption { enabled = true; kms_key_arn = "arn:aws:kms:..." }
}
```

**Incorrect (SQS/SNS):**
```hcl
resource "aws_sqs_queue" "fail" { name = "queue" }
resource "aws_sns_topic" "fail" {}
```

**Correct (SQS/SNS encrypted):**
```hcl
resource "aws_sqs_queue" "pass" { name = "queue"; sqs_managed_sse_enabled = true }
resource "aws_sns_topic" "pass" { kms_master_key_id = "alias/aws/sns" }
```

### Network Security

**Incorrect (public SSH):**
```hcl
resource "aws_security_group_rule" "fail" {
  type = "ingress"; protocol = "tcp"; from_port = 22; to_port = 22
  cidr_blocks = ["0.0.0.0/0"]
}
```

**Correct (restricted CIDR):**
```hcl
resource "aws_security_group_rule" "pass" {
  type = "ingress"; protocol = "tcp"; from_port = 22; to_port = 22
  cidr_blocks = ["10.0.0.0/8"]
}
```

**Incorrect (public IP):**
```hcl
resource "aws_instance" "fail" {
  ami = "ami-12345"; instance_type = "t3.micro"
  associate_public_ip_address = true
}
```

**Correct (no public IP):**
```hcl
resource "aws_instance" "pass" {
  ami = "ami-12345"; instance_type = "t3.micro"
  associate_public_ip_address = false
}
```

### Key Management

**Incorrect (KMS no rotation):**
```hcl
resource "aws_kms_key" "fail" { enable_key_rotation = false }
```

**Correct (KMS with rotation):**
```hcl
resource "aws_kms_key" "pass" { enable_key_rotation = true }
```

**Incorrect (CloudTrail):**
```hcl
resource "aws_cloudtrail" "fail" { name = "trail"; s3_bucket_name = "bucket" }
```

**Correct (CloudTrail encrypted):**
```hcl
resource "aws_cloudtrail" "pass" {
  name = "trail"; s3_bucket_name = "bucket"; kms_key_id = aws_kms_key.key.arn
}
```

### Credentials

**Incorrect (hardcoded):**
```hcl
provider "aws" {
  region = "us-west-2"; access_key = "AKIAEXAMPLE"; secret_key = "secret"
}
```

**Correct (external credentials):**
```hcl
provider "aws" {
  region = "us-west-2"; shared_credentials_file = "~/.aws/creds"; profile = "myprofile"
}
```
