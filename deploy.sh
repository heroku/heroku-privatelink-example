#!/usr/bin/env sh

set -euxo pipefail

# We need to always ensure we're pushing the most up-to-date binaries.
rm -f pg-test-privatelink.zip

# Move into the example program repo and compile. This will create a version
# that will work with AWS lambda.
cd source/pg-test-privatelink
GOOS=linux GOARCH=amd64  go build -o bin/pg-test-privatelink .
cd -

# Apply all terraform configs.
terraform apply -auto-approve
