#!/bin/sh

rm -rf ApiClient
openapi-generator-cli generate -g swift6 -i $@ -o ApiClient
