locals {
  tags = {
    created_by = "terraform"
  }

  aws_ecr_url           = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  docker_run_config_sha = sha256(local_file.docker_run_config.content)
}
