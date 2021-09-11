locals {
  tags = {
    created_by = "terraform"
  }

  docker_run_config_sha = filesha256(local_file.dockerrun.filename)
}
