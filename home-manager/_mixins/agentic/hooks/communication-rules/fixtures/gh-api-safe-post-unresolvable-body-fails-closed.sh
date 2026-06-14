#!/usr/bin/env bash

gh-api-safe repos/example/project/issues/42/comments --method POST --field body="$TRIPWIRE_BODY"
