data "aws_caller_identity" "current" {}

data "aws_elastic_beanstalk_hosted_zone" "current" {}

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

data "aws_ecr_repository" "repository" {
  for_each = toset(var.repository_list)
  name     = each.key
}

data "aws_route53_zone" "zone" {
  name = var.hosted_zone_name
}

data "aws_ecr_image" "image" {
  for_each        = toset(var.repository_list)
  repository_name = each.key
  image_tag       = "latest"
}
