locals {
  tags = {
    created_by = "terraform"
  }

  aws_ecr_url           = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  docker_run_config_sha = sha256(local_file.docker_run_config.content)
  backend_image_tag     = data.aws_ecr_image.image["backend"].image_tags[1] #try([for t in data.aws_ecr_image.image["backend"].image_tags : t if t != "latest"][0], "latest")
  worker_image_tag      = data.aws_ecr_image.image["worker"].image_tags[1]  #try([for t in data.aws_ecr_image.image["worker"].image_tags : t if t != "latest"][0], "latest")

}
