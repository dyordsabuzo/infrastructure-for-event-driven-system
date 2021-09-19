## Create ECR repository
resource "aws_ecr_repository" "repository" {
  for_each = toset(var.repository_list)
  name     = each.key
  tags     = local.tags
}

## Build docker images and push to ECR
resource "docker_registry_image" "image" {
  for_each = toset(var.repository_list)
  name     = "${aws_ecr_repository.repository[each.key].repository_url}:latest"

  build {
    context    = "../application"
    dockerfile = "${each.key}.Dockerfile"
  }
}

## Setup proper credentials to push to ECR

# Create docker run configuration file
resource "local_file" "docker_run_config" {
  depends_on = [docker_registry_image.image]
  content = jsonencode({
    AWSEBDockerrunVersion = 2
    containerDefinitions = [
      {
        name      = "backend"
        image     = "${aws_ecr_repository.repository["backend"].repository_url}:latest"
        memory    = 128
        essential = true
        portMappings = [{
          hostPort      = 80
          containerPort = var.backend_container_port
        }]
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
  key    = "${local.docker_run_config_sha}.zip"
  bucket = aws_s3_bucket.docker_run_bucket.id
  source = data.archive_file.docker_run.output_path
  tags   = local.tags
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
  name          = "event-driven-env"
  application   = aws_elastic_beanstalk_application.eb_app.name
  platform_arn  = "arn:aws:elasticbeanstalk:${var.region}::platform/Multi-container Docker running on 64bit Amazon Linux/2.26.4"
  version_label = aws_elastic_beanstalk_application_version.eb_version.name
  cname_prefix  = "event-driven-app"
  tags          = local.tags

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
    for_each = var.environment_variables_map
    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
    }
  }
}

# Setup output variable to show endpoint url to eb app
# Refer to variable in output.tf
