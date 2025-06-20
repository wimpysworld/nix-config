#!/usr/bin/bash -eu

# The first argument is the image to inspect
IMAGE=${1:-}
if [ -z "${IMAGE}" ]; then
  echo "Usage: ${0} <image>"
  echo "<image> is the image to inspect in the format cgr.dev/chainguard-private/conda:latest or cgr.dev/chainguard/curl:latest"
  exit 1
fi

# ensure that crane is present in PATH
if ! command -v crane &> /dev/null; then
  echo "crane could not be found. Please install crane."
  exit 1
fi

# inspect the image using crane
# first grab the manifest for the "architecture": "amd64",
architecture_specific_digest=$(crane manifest "${IMAGE}" | jq --raw-output '.manifests[] | select (.platform.architecture=="amd64") | .digest')

# then grab the layers and extract the package sboms listed in the layer - we assume a single layer
layer_digest=$(crane manifest "${IMAGE}@${architecture_specific_digest}" | jq --raw-output '.layers[] | select (.mediaType=="application/vnd.oci.image.layer.v1.tar+gzip") | .digest')

crane blob "${IMAGE}@${layer_digest}"  | tar -tvz var/lib/db/sbom
