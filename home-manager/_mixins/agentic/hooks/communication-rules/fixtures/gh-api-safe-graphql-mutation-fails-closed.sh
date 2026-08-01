#!/usr/bin/env bash

gh-api-safe graphql -f query='mutation{addComment(input:{subjectId:"PR_1",body:"A short reply."}){clientMutationId}}'
