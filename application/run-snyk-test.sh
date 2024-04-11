#!/bin/bash

snyk test --severity-threshold=medium --sarif-file-output=/snyk/output/snyk.sarif

if [ $? -ne  0 ]
then
    echo "Sny scan found vulnerabilities"
fi