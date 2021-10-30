

## Setup proper credentials to push to ECR

# Create docker run configuration file
resource "local_file" "docker_run_config" {
  content = yamlencode({
    version = "3.8"
    services = {
      backend = {
        image    = "${data.aws_ecr_repository.repository["backend"].repository_url}:${local.backend_image_tag}"
        ports    = ["80:${var.backend_container_port}"]
        env_file = [".env"]
      }
      worker = {
        image    = "${data.aws_ecr_repository.repository["worker"].repository_url}:${local.worker_image_tag}"
        env_file = [".env"]
      }
    }
  })
  filename = "${path.module}/docker-compose.yml"
}

# Compress the docker run config file
# Refer to data reference setup

# Create s3 bucket to store my docker run config
resource "aws_s3_bucket" "docker_run_bucket" {
  bucket = "docker-run-bucket"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

# Create s3 object from the compressed docker run config
resource "aws_s3_bucket_object" "docker_run_object" {
  key                    = "${local.docker_run_config_sha}.zip"
  bucket                 = aws_s3_bucket.docker_run_bucket.id
  source                 = data.archive_file.docker_run.output_path
  tags                   = local.tags
  server_side_encryption = "AES256"
}

# Create instance profile
resource "aws_iam_instance_profile" "ec2_eb_profile" {
  name = "event-driven-ec2-profile"
  role = aws_iam_role.ec2_role.name
  tags = local.tags
}

resource "aws_iam_role" "ec2_role" {
  name               = "event-driven-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  ]

  inline_policy {
    name   = "eb-application-permissions"
    policy = data.aws_iam_policy_document.permissions.json
  }
  tags = local.tags
}

# Create eb app
resource "aws_elastic_beanstalk_application" "eb_app" {
  name        = "event-driven-app"
  description = "event-driven-app beanstalk deployment"
  tags        = local.tags
}

# Create eb version
resource "aws_elastic_beanstalk_application_version" "eb_version" {
  name        = local.docker_run_config_sha
  application = aws_elastic_beanstalk_application.eb_app.name
  description = "application version created by terraform"
  bucket      = aws_s3_bucket.docker_run_bucket.id
  key         = aws_s3_bucket_object.docker_run_object.id
  tags        = local.tags
}

# Create eb environment
resource "aws_elastic_beanstalk_environment" "eb_env" {
  name                = "event-driven-env"
  application         = aws_elastic_beanstalk_application.eb_app.name
  solution_stack_name = "64bit Amazon Linux 2 v3.4.6 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.eb_version.name
  cname_prefix        = "event-driven-app"
  tags                = local.tags

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_eb_profile.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = var.max_instance_count
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "internet facing"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "MatcherHTTPCode"
    value     = 200
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/docs"
  }

  dynamic "setting" {
    for_each = merge(var.environment_variables_map, {
      THUMBNAIL_BASE_URL = "https://${aws_s3_bucket.thumbnail_bucket.bucket_regional_domain_name}/thumbnail"
      S3_BUCKET_NAME     = aws_s3_bucket.thumbnail_bucket.bucket
      QUEUE_NAME         = aws_sqs_queue.queue.name
      BROKER_TYPE        = "sqs"
      AWS_DEFAULT_REGION = var.region
    })
    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
    }
  }

  dynamic "setting" {
    for_each = {
      Protocol           = "HTTPS"
      SSLCertificateArns = aws_acm_certificate.cert.arn
      SSLPolicy          = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
    }
    content {
      namespace = "aws:elbv2:listener:443"
      name      = setting.key
      value     = setting.value
    }
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "ListenerEnabled"
    value     = false
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = true
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "MinInstancesInService"
    value     = 1
  }
}

# Setup output variable to show endpoint url to eb app
# Refer to variable in output.tf

resource "aws_route53_record" "endpoint" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.endpoint_name
  type    = "A"

  alias {
    name                   = aws_elastic_beanstalk_environment.eb_env.cname
    zone_id                = data.aws_elastic_beanstalk_hosted_zone.current.id
    evaluate_target_health = true
  }

}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.hosted_zone_name
  subject_alternative_names = ["*.${var.hosted_zone_name}"]
  validation_method         = "DNS"
  tags                      = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation_record" {
  for_each = {
    for d in aws_acm_certificate.cert.domain_validation_options : d.domain_name => {
      name   = d.resource_record_name
      record = d.resource_record_value
      type   = d.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
}

resource "aws_acm_certificate_validation" "validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_record : record.fqdn]
}

resource "aws_s3_bucket" "thumbnail_bucket" {
  bucket = "event-driven-thumbnail-bucket"
  acl    = "private"
  tags   = local.tags

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.thumbnail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = ["${aws_s3_bucket.thumbnail_bucket.arn}/thumbnail/*"]
      }
    ]
  })
}

resource "aws_sqs_queue" "queue" {
  name                              = "event-driven-queue"
  kms_master_key_id                 = "alias/aws/sqs"
  kms_data_key_reuse_period_seconds = 300
}
