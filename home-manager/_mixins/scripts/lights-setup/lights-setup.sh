#!/usr/bin/env bash

PROFILE=$(obs-cli profile get)

case "${PROFILE}" in
  Dev)
    hue-lights default
    key-lights default
    ;;
  Play)
    hue-lights default
    key-lights gaming
    ;;
esac
