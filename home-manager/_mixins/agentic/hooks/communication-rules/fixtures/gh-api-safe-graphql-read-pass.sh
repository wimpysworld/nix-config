#!/usr/bin/env bash

gh-api-safe graphql -f query='{repository(owner:"linuxmatters",name:"ffmpeg-statigo"){pullRequest(number:65){reviewThreads(first:20){nodes{isResolved path}}}}}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)'
