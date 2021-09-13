####### I need to create a docker repository
resource "aws_ecr_repository" "repository" {
  for_each = toset(var.repositories)
  name     = each.key
  tags     = local.tags
}

resource "docker_registry_image" "image" {
  for_each = toset(var.repositories)
  name     = "${aws_ecr_repository.repository[each.key].repository_url}:latest"
  build {
    context    = "../../application"
    dockerfile = "${each.key}.Dockerfile"
  }
}
#######

resource "local_file" "dockerrun" {
  content = jsonencode({
    AWSEBDockerrunVersion = 2
    containerDefinitions = [
      {
        name      = "backend"
        image     = "${aws_ecr_repository.repository["backend"].repository_url}:latest"
        memory    = 128
        essential = true
        portMappings = [
          {
            hostPort      = 80
            containerPort = 8080
          }
        ]
      },
      {
        name      = "worker"
        image     = "${aws_ecr_repository.repository["worker"].repository_url}:latest"
        memory    = 128
        essential = true
      }
    ]
  })
  filename = "${path.module}/Dockerrun.aws.json"
  # depends_on = [null_resource.image]
  depends_on = [
    docker_registry_image.image
  ]
}

data "archive_file" "docker_run" {
  type        = "zip"
  source_file = local_file.dockerrun.filename
  output_path = "${path.module}/Dockerrun.aws.zip"
}

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

resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket                  = aws_s3_bucket.docker_run_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_object" "docker_run_object" {
  key    = "${sha256(local_file.dockerrun.content)}.zip"
  bucket = aws_s3_bucket.docker_run_bucket.id
  source = data.archive_file.docker_run.output_path
  tags   = local.tags
}

resource "aws_iam_role" "ec2_role" {
  name               = "event-driven-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  ]

  inline_policy {
    name   = "eb-application-permissions"
    policy = data.aws_iam_policy_document.permission_policy.json
  }
  tags = local.tags
}

resource "aws_iam_instance_profile" "ec2_eb_profile" {
  name = "event-driven-ec2-profile"
  role = aws_iam_role.ec2_role.name
  tags = local.tags
}

resource "aws_elastic_beanstalk_application" "eb_app" {
  name        = "event-driven-app"
  description = "Event Driven App beanstalk deployment"
  tags        = local.tags
}

resource "aws_elastic_beanstalk_environment" "eb_env" {
  name          = "event-driven-env"
  application   = aws_elastic_beanstalk_application.eb_app.name
  platform_arn  = "arn:aws:elasticbeanstalk:${var.region}::platform/Multi-container Docker running on 64bit Amazon Linux/2.26.4"
  cname_prefix  = "event-driven-app"
  version_label = aws_elastic_beanstalk_application_version.eb_version.name
  tags          = local.tags

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_eb_profile.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 2
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
    for_each = var.environment_variables_map
    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
    }
  }
}

resource "aws_elastic_beanstalk_application_version" "eb_version" {
  name        = sha256(local_file.dockerrun.content)
  application = aws_elastic_beanstalk_application.eb_app.name
  description = "application version created by terraform"
  bucket      = aws_s3_bucket.docker_run_bucket.id
  key         = aws_s3_bucket_object.docker_run_object.id
  tags        = local.tags
}


