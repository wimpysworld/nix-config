#!/usr/bin/env bash

gh-api-safe graphql -f query='{repository(owner:"linuxmatters",name:"ffmpeg-statigo"){pullRequest(number:65){reviewThreads(first:20){nodes{isResolved path}}}}}' && gh run view 42 --json jobs --jq '.jobs[].steps[] | select(.conclusion=="failure")'
