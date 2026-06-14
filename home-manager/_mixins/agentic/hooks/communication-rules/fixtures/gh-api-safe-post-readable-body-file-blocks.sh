#!/usr/bin/env bash

gh-api-safe markdown --method POST --field text=@post-body-blocks.txt
