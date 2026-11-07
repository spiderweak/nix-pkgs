#!/usr/bin/env bash
# Update sources.json to the latest instawow release on PyPI.
#
# Usage (from the repo root):
#   nix develop -c pkgs/instawow/update.sh           # only if a new version exists
#   nix develop -c pkgs/instawow/update.sh --force   # recompute the hash anyway
#
# Needs: curl, jq, nix (with the nix-command feature enabled).
#
# Only version and hash are updated. If the new release changes its
# dependencies, package.nix needs editing by hand (the build fails until then).
set -euo pipefail

cd "$(dirname "$0")"

force=false
[ "${1:-}" = "--force" ] && force=true

version=$(curl -fsSL "https://pypi.org/pypi/instawow/json" | jq -r .info.version)

# Final releases and post-releases only (e.g. 7.3.0, 7.0.0.post1).
if ! [[ "$version" =~ ^[0-9]+(\.[0-9]+)*(\.post[0-9]+)?$ ]]; then
  echo "instawow: unexpected version string: '$version'" >&2
  exit 1
fi

current=$(jq -r .version sources.json)
if [ "$version" = "$current" ] && [ "$force" = false ]; then
  echo "instawow: already at $current"
  exit 0
fi

url="https://files.pythonhosted.org/packages/source/i/instawow/instawow-$version.tar.gz"
echo "instawow: fetching $version to compute its hash..."
hash=$(nix store prefetch-file --json "$url" | jq -r .hash)

jq -n --arg v "$version" --arg h "$hash" '{version: $v, hash: $h}' > sources.json
echo "instawow: $current -> $version"
