#!/bin/bash

snyk test --sarif-file-output=/snyk/output/snyk.sarif \
    --severity-threshold=medium

if [ $? -ne 0 ] 
then
  echo "Snyk scanning found vulnerabilities"
else
  rm /snyk/output/snyk.sarif
fi