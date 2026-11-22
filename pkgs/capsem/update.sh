#!/usr/bin/env bash
# Update sources.json to the latest Capsem release.
#
# Usage (from the repo root):
#   nix develop -c pkgs/capsem/update.sh           # only if a new version exists
#   nix develop -c pkgs/capsem/update.sh --force   # recompute the hash anyway
#
# Needs: curl, jq, nix (with the nix-command feature enabled).
set -euo pipefail

cd "$(dirname "$0")"

force=false
[ "${1:-}" = "--force" ] && force=true

# GitHub's "latest release" skips prereleases. Capsem also publishes VM-image
# releases (runtime-*, profile-*) in the same repository; only v* tags are app
# releases, so anything else is rejected below.
tag=$(curl -fsSL "https://api.github.com/repos/google/capsem/releases/latest" | jq -r .tag_name)
version=${tag#v}

if ! [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "capsem: latest release is not an app release: '$tag'" >&2
  exit 1
fi

current=$(jq -r .version sources.json)
if [ "$version" = "$current" ] && [ "$force" = false ]; then
  echo "capsem: already at $current"
  exit 0
fi

url="https://github.com/google/capsem/releases/download/$tag/Capsem_${version}_amd64.deb"
echo "capsem: fetching $version to compute its hash..."
hash=$(nix store prefetch-file --json "$url" | jq -r .hash)

jq -n --arg v "$version" --arg h "$hash" '{version: $v, hash: $h}' > sources.json
echo "capsem: $current -> $version"
