#!/usr/bin/env bash

echo "$(pulsemixer --get-volume | cut -d' ' -f1)"%
