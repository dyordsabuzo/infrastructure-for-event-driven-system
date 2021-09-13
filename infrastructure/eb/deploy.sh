#!/bin/bash
set -e

SCRIPT_PATH=$(dirname "$0")

[ -z $TF_WORKSPACE ] && \
    echo "NOTE: You are using the default TFVARS infrastructure/tfvars/main.tfvars" && \
    TF_WORKSPACE=main

cd $SCRIPT_PATH

terraform init
terraform validate

if [ ! -z $DESTROY ] && [ "$DESTROY" == "true" ]
then
    terraform plan -var-file tfvars/$TF_WORKSPACE.tfvars -out $TF_WORKSPACE.tfplan -destroy
else
    terraform plan -var-file tfvars/$TF_WORKSPACE.tfvars -out $TF_WORKSPACE.tfplan
fi

terraform apply $TF_WORKSPACE.tfplan

if [ "$DESTROY" != "true" ]
then
    endpoint=$(terraform output -raw endpoint_url)
    echo "Running post deployment verification for http://${endpoint}/docs"
    status_code=$(curl -w "%{http_code}\n" ${endpoint}/docs -o output.txt -s)

    [ "$status_code" != "200" ] && \
        echo "FAILED: Post deployment verification with status code ${status_code}" &&
        exit 1
    echo "SUCCESS: Post deployment verification with status code ${status_code}"
    
fi

echo "COMPLETE: Infrastructure deployment"


