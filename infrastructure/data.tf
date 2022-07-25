data "aws_caller_identity" "current" {}

data "aws_elastic_beanstalk_hosted_zone" "current" {}

data "aws_elastic_beanstalk_hosted_zone" "current" {}

data "archive_file" "docker_run" {
  type        = "zip"
  source_dir  = "${path.module}/ebsource"
  output_path = "${path.module}/Dockerrun.aws.zip"

  depends_on = [
    local_file.docker_run_config
  ]
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

data "aws_route53_zone" "zone" {
  name = var.hosted_zone_name
}
