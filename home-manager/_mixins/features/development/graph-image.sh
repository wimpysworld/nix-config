#!/usr/bin/env bash
set -eu
# Display a graph of the resolved packages present in an image using apko dot
# Example usage
# image-dependency-graph.sh "cgr.dev/chainguard-private/aws-cli:latest"
# image-dependency-graph.sh "cgr.dev/chainguard-private/aws-cli:2.24.9-r0"

IMAGE_URL=${1:-}
if [ -z "${IMAGE_URL}" ]; then
  echo "Usage: ${0} <image-url>"
  echo "Example: ${0} cgr.dev/chainguard/static:latest"
  exit 1
fi
echo "** Note ** This queries amd64 images only"
# strip the tag from the image URL
IMAGE_URL_WITHOUT_TAG=$(echo "${IMAGE_URL}" | cut --delimiter=: --fields=1)

# Use crane to get the manifest from the image using the full image url
# crane manifest ${IMAGE_URL} | jq .
manifest_json=$(crane manifest "${IMAGE_URL}")

# From the result select from the manifests the digest with platform architecture amd64
amd64_digest=$(echo "${manifest_json}" | jq --raw-output '.manifests[] | select(.platform.architecture == "amd64") | .digest')

# construct the full attestation URL for this digest
# replace colon with - in the digest
# shellcheck disable=SC2001
amd64_digest_attestation_url=$(echo "${amd64_digest}" | sed 's/:/-/g')
attestation_url="${IMAGE_URL_WITHOUT_TAG}:${amd64_digest_attestation_url}.att"
# Get the attestation from the attestation URL and then get the image configuration digest from that attestation
attestation=$(crane manifest "${attestation_url}")
image_configuration_digest=$(echo "${attestation}" | jq --raw-output '.layers[] | select(.mediaType == "application/vnd.dsse.envelope.v1+json" and .annotations.predicateType == "https://apko.dev/image-configuration") | .digest')
# Use that config digest to get the image configuration blob
image_configuration_blob=$(crane blob "${IMAGE_URL_WITHOUT_TAG}@${image_configuration_digest}")
# The config we want is in the payload which is base64 encoded
image_configuration_payload_base64=$(echo "${image_configuration_blob}" | jq --raw-output '.payload')
image_configuration_payload=$(echo "${image_configuration_payload_base64}" | base64 --decode)
# The config we want from this payload is the predicate which we can then pass to apko dot
image_config_predicate=$(echo "${image_configuration_payload}" | jq --raw-output '.predicate')
# write predicate to temporary file in a temporary directory
temp_dir=$(mktemp --directory)
echo "${image_config_predicate}" > "${temp_dir}/predicate.json"
apko dot --web "${temp_dir}/predicate.json"
