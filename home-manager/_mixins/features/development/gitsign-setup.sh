#!/usr/bin/env bash

if [ -d .git ]; then
  git config --local commit.gpgsign true
  git config --local tag.gpgsign true
  git config --local gpg.x509.program gitsign
  git config --local gpg.format x509
  git config --local gitsign.connectorID https://accounts.google.com
else
  echo "No Git repository found. Exiting."
  exit 1
fi
