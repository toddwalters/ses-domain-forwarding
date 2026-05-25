#!/usr/bin/env bash

set -euo pipefail

tracked_tfvars="$(git ls-files '*.tfvars' '*.tfvars.json')"

if [ -n "${tracked_tfvars}" ]; then
  echo "Tracked Terraform variable files are not allowed:"
  echo "${tracked_tfvars}"
  echo ""
  echo "Keep real tfvars files untracked and use committed *.example files for samples."
  exit 1
fi

echo "No tracked Terraform variable files found."
