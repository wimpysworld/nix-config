#!/usr/bin/env bash
# Shared pull request opener for the Package Freshener workflow.
#
# Consumes these environment variables:
#   PKG_ID     short package identifier, used in the branch name
#   PKG_NAME   human-readable name, used in the pull request body
#   CHANGELOG  upstream changelog or release URL
#   VERSION    version or short revision the update moved to
#   FILES      space-separated list of files to stage
#   GH_TOKEN   token with permission to push and open pull requests
set -euo pipefail

BRANCH_VERSION=$VERSION
if ! git check-ref-format --branch "${PKG_ID}-${BRANCH_VERSION}" >/dev/null 2>&1; then
  BRANCH_VERSION=$(printf '%s' "$VERSION" \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | LC_ALL=C tr -cs 'a-z0-9' '-')
  BRANCH_VERSION=${BRANCH_VERSION#-}
  BRANCH_VERSION=${BRANCH_VERSION%-}
fi

if [[ -z "$BRANCH_VERSION" ]]; then
  echo "❌ Version '${VERSION}' cannot form a branch name"
  exit 1
fi

BRANCH="${PKG_ID}-${BRANCH_VERSION}"

# Skip when a pull request already exists for this exact branch.
if gh pr list --search "head:${BRANCH}" --json number --jq '.[0].number' | grep -q .; then
  echo "⏭️  PR already exists for ${BRANCH}"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout -b "$BRANCH"
# shellcheck disable=SC2086
git add $FILES
git commit -m "chore(${PKG_ID}): update to ${VERSION}"
git push -u origin "$BRANCH"

PR_URL=$(gh pr create \
  --title "chore(${PKG_ID}): update to ${VERSION}" \
  --body "Automated ${PKG_NAME} update to ${VERSION}.

Changelog: ${CHANGELOG}" \
  --label "dependencies,automated")

echo "📋 Created PR: ${PR_URL}"

PR_NUMBER=$(echo "$PR_URL" | grep -o '[0-9]*$')
if ! gh pr merge --auto --squash "$PR_NUMBER"; then
  echo "::warning::Pull request ${PR_NUMBER} was created, but auto-merge could not be enabled"
fi
