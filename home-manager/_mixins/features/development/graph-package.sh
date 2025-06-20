#!/usr/bin/env bash
set -eu
# Display a graph of the resolved package dependency tree using apko dot
# Multiple packages can be provided as arguments
# Example usage
# package-dependency-graph.sh "aws-cli-2=2.24.9-r0" "curl" "google-guest-agent"


# Display help if no arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: ${0} package1 [package2 ... package3]"
    echo "Description:  Display a graph of the resolved package dependency tree using apko dot command."
    echo "Multiple packages can be provided as arguments"
    echo "Example: ${0} aws-cli-2=2.24.9-r0 curl google-guest-agent"
    exit 1
fi

# Initialize empty result string
package_string=""

# Loop through all packages and concatenate them into a single command separated string
for arg in "$@"; do
    # Add comma if not first argument
    if [ -n "${package_string}" ]; then
        package_string="${package_string},"
    fi
    package_string="${package_string}\"${arg}\""
done

# Print the final result
echo "Querying ${package_string}"
echo "** Note ** This queries amd64 packages only"

# write predicate to temporary file in a temporary directory
temp_dir=$(mktemp --directory)

# use here document to pass the predicate to apko dot
cat > "${temp_dir}/predicate.json" << EOF
{
  "archs": [
    "amd64"
  ],
  "contents": {
    "build_repositories": [
      "https://apk.cgr.dev/chainguard-private"
    ],
    "keyring": [
      "https://packages.cgr.dev/extras/chainguard-extras.rsa.pub",
      "https://packages.wolfi.dev/os/wolfi-signing.rsa.pub"
    ],
    "packages": [
      ${package_string}
    ],
    "repositories": [
      "https://packages.cgr.dev/extras",
      "https://packages.wolfi.dev/os"
    ]
  }
}
EOF

apko dot --web "${temp_dir}/predicate.json"
