#!/bin/bash
set -euo pipefail

# Build a VPM (VRChat Package Manager) listing from the repository's releases.
#
# It walks every published GitHub Release, downloads the `package.json` attached
# to each one, and assembles a single `index.json` listing where each package
# version's manifest is the contents of that `package.json` plus a `url` field
# pointing at the release's `.zip` asset. A minimal `index.html` is produced
# alongside it. Both are written into `_site/` for GitHub Pages.

REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}" # owner/repo
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"

# `actions/configure-pages` exposes the resolved base URL (handles project /
# user / custom-domain pages). Fall back to the conventional project pages URL.
BASE_URL="${PAGES_BASE_URL:-https://${OWNER}.github.io/${NAME}}"
BASE_URL="${BASE_URL%/}"

LISTING_ID="$(printf 'io.github.%s.%s' "$OWNER" "$NAME" | tr '[:upper:]' '[:lower:]')"
LISTING_URL="${BASE_URL}/index.json"
LISTING_NAME="${OWNER} VPM Listing"

OUT_DIR="_site"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fetch every release (paginated).
gh api --paginate "repos/${REPO}/releases" > "$WORK/releases.json"

echo '{}' > "$WORK/packages.json"
AUTHOR=""

count="$(jq 'length' "$WORK/releases.json")"
for i in $(seq 0 $((count - 1))); do
  release="$(jq ".[$i]" "$WORK/releases.json")"

  pkg_asset_id="$(jq -r '(.assets[] | select(.name == "package.json") | .id) // empty' <<<"$release")"
  zip_url="$(jq -r '[.assets[] | select(.name | endswith(".zip")) | .browser_download_url][0] // empty' <<<"$release")"

  # Skip releases that are not VPM packages (missing package.json or zip).
  [ -n "$pkg_asset_id" ] || continue
  [ -n "$zip_url" ] || continue

  # The asset API streams the binary content (works for private repos too).
  if ! gh api -H "Accept: application/octet-stream" \
      "repos/${REPO}/releases/assets/${pkg_asset_id}" > "$WORK/pkg.json" 2>/dev/null; then
    echo "WARN: failed to download package.json for release index $i; skipping" >&2
    continue
  fi

  if ! pname="$(jq -er '.name' "$WORK/pkg.json")" \
      || ! pver="$(jq -er '.version' "$WORK/pkg.json")"; then
    echo "WARN: invalid package.json for release index $i; skipping" >&2
    continue
  fi

  # manifest = package.json contents + download url for this version's zip.
  manifest="$(jq --arg url "$zip_url" '. + {url: $url}' "$WORK/pkg.json")"

  jq --arg name "$pname" --arg ver "$pver" --argjson manifest "$manifest" \
    '.[$name].versions[$ver] = $manifest' "$WORK/packages.json" > "$WORK/packages.tmp"
  mv "$WORK/packages.tmp" "$WORK/packages.json"

  # Releases are returned newest-first, so the first author we see is the latest.
  if [ -z "$AUTHOR" ]; then
    AUTHOR="$(jq -r '(.author.name // .author) // empty' "$WORK/pkg.json")"
  fi
done

[ -n "$AUTHOR" ] || AUTHOR="$OWNER"

# Assemble the listing.
jq -n \
  --arg name "$LISTING_NAME" \
  --arg id "$LISTING_ID" \
  --arg url "$LISTING_URL" \
  --arg author "$AUTHOR" \
  --slurpfile packages "$WORK/packages.json" \
  '{name: $name, id: $id, url: $url, author: $author, packages: $packages[0]}' \
  > "$OUT_DIR/index.json"

# Build a bare-bones HTML index from the generated listing.
pkg_items="$(jq -r '
  .packages | to_entries[]
  | .key as $id
  | (.value.versions | to_entries | max_by(.key) | .value) as $latest
  | "    <li>" + (($latest.displayName // $id) | @html)
    + " (<code>" + ($id | @html) + "</code>)"
    + " &mdash; " + (.value.versions | keys | join(", ") | @html)
    + "</li>"
' "$OUT_DIR/index.json")"

[ -n "$pkg_items" ] || pkg_items="    <li>No packages published yet.</li>"

listing_url_html="$(printf '%s' "$LISTING_URL" | jq -Rr '@html')"
listing_url_uri="$(printf '%s' "$LISTING_URL" | jq -Rr '@uri')"
listing_name_html="$(printf '%s' "$LISTING_NAME" | jq -Rr '@html')"

cat > "$OUT_DIR/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${listing_name_html}</title>
</head>
<body>
  <h1>${listing_name_html}</h1>
  <p>VPM listing for use with the VRChat Creator Companion (VCC) / ALCOM.</p>
  <p>
    <a href="vcc://vpm/addRepo?url=${listing_url_uri}">Add to VCC</a>
  </p>
  <p>
    Listing URL: <a href="${listing_url_html}">${listing_url_html}</a>
  </p>
  <h2>Packages</h2>
  <ul>
${pkg_items}
  </ul>
</body>
</html>
HTML

echo "Generated ${OUT_DIR}/index.json and ${OUT_DIR}/index.html"
