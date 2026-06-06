#!/bin/bash
set -euxo pipefail

PACKAGE_NAME="$(jq -r '.name' package.json)"
PACKAGE_VERSION="$(jq -r '.version' package.json)"
PACKAGE_ZIP="${PACKAGE_NAME}-${PACKAGE_VERSION}.zip"
GIT_TAG="v${PACKAGE_VERSION}"

# check tag exists
if git ls-remote --tags origin | cut -f2 | grep -qF "refs/tags/$GIT_TAG"; then
  echo "ERROR: tag:$GIT_TAG already exists on repository. Update version on package.json."
  exit 1
fi

# push tag
git tag "$GIT_TAG"
git push origin "$GIT_TAG"

# mark as pre-release when version is a SemVer pre-release (contains '-')
PRERELEASE_FLAG=()
if [[ "$PACKAGE_VERSION" == *-* ]]; then
  PRERELEASE_FLAG=(--prerelease)
fi

# create Release
zip -x '.*' -r "$PACKAGE_ZIP" .
gh release create --generate-notes "${PRERELEASE_FLAG[@]}" "$GIT_TAG" package.json "$PACKAGE_ZIP"
