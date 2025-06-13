#!/usr/bin/env bash

if [ ! -d .git ]; then
  echo "This script must be run in a git repository."
  exit 1
fi

if [ -e .git/hooks/pre-commit ]; then
  echo "Pre-commit hook already exists. Skipping installation."
  exit 0
fi

if [ -e .pre-commit-config.yaml ]; then
  pre-commit install
  pre-commit run --all-files
else
  echo "No .pre-commit-config.yaml found. Please create one to use pre-commit hooks."
  exit 1
fi
