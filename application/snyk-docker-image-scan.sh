#!/bin/bash
set -e

image_name=$1
[ -z $image_name ] && echo "Image name required" && exit 1

image_tag=$image_name

[ ! -z "$ECR_REGISTRY" ] && image_tag="$ECR_REGISTRY/$image_tag:$IMAGE_TAG"

script_path=$(dirname "$0")
cd $script_path

docker run --rm -it --env SNYK_TOKEN \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $PWD:/src \
    snyk/snyk:docker \
    snyk test --docker $image_tag --file=/src/$image_name.Dockerfile \
        --sarif-file-output=/src/$image_name.scan.sarif