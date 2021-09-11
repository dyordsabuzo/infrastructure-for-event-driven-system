####### I need to create a docker repository
resource "aws_ecr_repository" "backend" {
  name = "thumbnail-backend"
}

resource "aws_ecr_repository" "worker" {
  name = "thumbnail-worker"
}

resource "docker_registry_image" "backend" {
  name = "${aws_ecr_repository.backend.repository_url}:latest"
  build {
    context    = "../../application"
    dockerfile = "backend.Dockerfile"
  }
}

resource "docker_registry_image" "worker" {
  name = "${aws_ecr_repository.worker.repository_url}:latest"
  build {
    context    = "../../application"
    dockerfile = "worker.Dockerfile"
  }
}
#######



resource "local_file" "dockerrun" {
  content = jsonencode({
    AWSEBDockerrunVersion = 2
    containerDefinitions = [
      {
        name      = "thumbnail-backend"
        image     = "${aws_ecr_repository.backend.repository_url}:latest"
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
        name      = "thumbnail-worker"
        image     = "${aws_ecr_repository.worker.repository_url}:latest"
        memory    = 128
        essential = true
      }
    ]
  })
  filename = "${path.module}/Dockerrun.aws.json"
}

data "archive_file" "docker_run" {
  type        = "zip"
  source_file = local_file.dockerrun.filename
  output_path = "${path.module}/Dockerrun.aws.zip"
}

resource "aws_s3_bucket" "docker_run_bucket" {
  bucket = "docker-run-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket                  = aws_s3_bucket.docker_run_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_object" "docker_run_object" {
  key    = "Dockerrun.aws.zip"
  bucket = aws_s3_bucket.docker_run_bucket.id
  source = data.archive_file.docker_run.output_path
}

resource "aws_iam_role" "ec2_role" {
  name               = "event-driven-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_policy.json

  inline_policy {
    name   = "eb-application-permissions"
    policy = data.aws_iam_policy_document.permission_policy.json
  }
}

resource "aws_iam_instance_profile" "ec2_eb_profile" {
  name = "event-driven-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_elastic_beanstalk_application" "event_driven_app" {
  name        = "event-driven-app"
  description = "Event Driven App beanstalk deployment"
}

resource "aws_elastic_beanstalk_environment" "event_driven_env" {
  name                = "event-driven-env"
  application         = aws_elastic_beanstalk_application.event_driven_app.name
  solution_stack_name = "64bit Amazon Linux 2 v3.4.5 running Docker"
  cname_prefix        = "event-driven-app"
  version_label       = aws_elastic_beanstalk_application_version.event_driven_version.name

  # setting {
  #   namespace = "aws:autoscaling:launchconfiguration"
  #   name      = "IamInstanceProfile"
  #   value     = var.instance_role
  # }

  # setting {
  #   namespace = "aws:elasticbeanstalk:environment"
  #   name      = "LoadBalancerType"
  #   value     = "application"
  # }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_eb_profile.name
  }
}

resource "aws_elastic_beanstalk_application_version" "event_driven_version" {
  name        = local.docker_run_config_sha
  application = aws_elastic_beanstalk_application.event_driven_app.name
  description = "application version created by terraform"
  bucket      = aws_s3_bucket.docker_run_bucket.id
  key         = aws_s3_bucket_object.docker_run_object.id
}


