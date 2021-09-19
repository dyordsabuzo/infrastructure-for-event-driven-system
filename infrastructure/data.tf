data "aws_caller_identity" "current" {}

data "aws_ecr_authorization_token" "token" {}

data "archive_file" "docker_run" {
  type        = "zip"
  source_file = local_file.docker_run_config.filename
  output_path = "${path.module}/Dockerrun.aws.zip"
}

data "aws_iam_policy_document" "assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "permissions" {
  statement {
    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeInstanceStatus",
      "ssm:*",
      "ec2messages:*",
      "s3:*",
      "sqs:*"
    ]
    resources = ["*"]
  }
}
