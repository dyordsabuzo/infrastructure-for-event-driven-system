## Create ECR repository
resource "aws_ecr_repository" "repository" {
  for_each = toset(var.repository_list)
  name     = each.key
}

## Build docker images and push to ECR
resource "docker_registry_image" "backend" {
  for_each = toset(var.repository_list)
  name     = "${aws_ecr_repository.repository[each.key].repository_url}:latest"

  build {
    context    = "../application"
    dockerfile = "${each.key}.Dockerfile"
  }
}


## Setup proper credentials to push to ECR

resource "aws_ecr_replication_configuration" "ecr" {
  replication_configuration {
    rule {
      dynamic "destination" {
        for_each = toset(var.replication_regions)

        content {
          region      = destination.key
          registry_id = data.aws_caller_identity.current.account_id
        }
      }

      repository_filter {
        filter_type = "PREFIX_MATCH"
        filter      = "ps-"
      }
    }
  }
}
