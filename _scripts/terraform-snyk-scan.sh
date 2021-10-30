#!/bin/bash
set -e

[ -z "$SNYK_TOKEN" ] && echo "SNYK_TOKEN required" && exit 1
[ -z "$TF_CODE_PATH" ] && echo "TF_CODE_PATH required" && exit 1


docker run -e SNYK_TOKEN \
    -v $TF_CODE_PATH:/infra \
    -w /infra \
    snyk/snyk:alpine snyk iac test \
    --sarif-file-output=terraform.snyk.sarif