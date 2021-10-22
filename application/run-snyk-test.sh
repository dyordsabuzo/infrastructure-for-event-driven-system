#!/bin/bash

snyk test --sarif-file-output=/snyk/output/snyk.sarif

if [ $? -ne  0 ]
then
    echo "Sny scan found vulnerabilities"
fi