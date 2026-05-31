#!/bin/bash
set -euo pipefail

#GH_PAGES_BASE_URL='<will be given from ci variable>'
#GITHUB_REPOSITORY='<will be given from ci variable>'

PACKAGE_NAME="$(jq -r '.displayName' package.json)"
PACKAGE_ID="$(jq -r '.name' package.json)"
PACKAGE_AUTHOR="$(jq -r '.author.name' package.json)"

rm -rf public && mkdir public
pushd public

# vpm.json: listing関連キーの設定
vpm_json="{}"
vpm_json="$(echo "$vpm_json" | jq --arg v "$PACKAGE_NAME" '.name = $v')"
vpm_json="$(echo "$vpm_json" | jq --arg v "$PACKAGE_ID-repo" '.id = $v')"
vpm_json="$(echo "$vpm_json" | jq --arg v "$PACKAGE_AUTHOR" '.author = $v')"
vpm_json="$(echo "$vpm_json" | jq --arg v "$GH_PAGES_BASE_URL/vpm.json" '.url = $v')"

# vpm.json: リリースのpackage.jsonとzipファイルのURLを組み込み
for tag in $(gh release list --json tagName | jq -r '.[].tagName'); do
  release_json="$(gh release view "$tag" --json assets --jq '.assets[]|select(.name|test("^package.json$")).name' | head -1)"
  release_zip="$(gh release view "$tag" --json assets --jq '.assets[]|select(.name|test(".zip$")).name' | head -1)"
  release_zip_sha256="$(gh release view "v0.1.0-dev" --json assets --jq '.assets[]|select(.name|test(".zip$")).digest' | head -1 | cut -d: -f2)"

  if [ -n "$release_json" ] && [ -n "$release_zip" ]; then
    gh release download --clobber --pattern "package.json"
    release_json_content="$(jq . package.json)"
    release_json_content="$(echo "$release_json_content" | jq --arg v "https://github.com/${GITHUB_REPOSITORY}/releases/download/$tag/$release_zip" '.url = $v')"
    release_json_content="$(echo "$release_json_content" | jq --arg v "$release_zip_sha256" '.zipSHA256 = $v')"

    vpm_json="$(echo "$vpm_json" | jq --argjson d "$release_json_content" ".packages.\"${PACKAGE_ID}\".versions.\"${tag:1}\" = \$d")"
  fi
  rm package.json
done

echo "$vpm_json" > vpm.json

cat > index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${PACKAGE_NAME}</title>
</head>
<body>
  <h1>${PACKAGE_NAME}</h1>
  <p>VPM listing for use with the VRChat Creator Companion (VCC).</p>
  <p>
    <a href="vcc://vpm/addRepo?url=${GH_PAGES_BASE_URL}/vpm.json">Add to VCC</a>
  </p>
</body>
</html>
HTML
popd
