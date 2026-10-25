#!/usr/bin/env bash
# Update sources.json to the latest Claude Code release.
#
# Usage (from the repo root):
#   nix develop -c pkgs/claude-code/update.sh           # only if a new version exists
#   nix develop -c pkgs/claude-code/update.sh --force   # recompute the hash anyway
#
# Needs: curl, jq, nix (with the nix-command feature enabled).
set -euo pipefail

cd "$(dirname "$0")"

force=false
[ "${1:-}" = "--force" ] && force=true

# Latest version number, from the npm registry (independent of the download host).
version=$(curl -fsSL "https://registry.npmjs.org/@anthropic-ai%2fclaude-code/latest" | jq -r .version)

if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "claude-code: unexpected version string: '$version'" >&2
  exit 1
fi

current=$(jq -r .version sources.json)
if [ "$version" = "$current" ] && [ "$force" = false ]; then
  echo "claude-code: already at $current"
  exit 0
fi

url="https://downloads.claude.ai/claude-code-releases/$version/linux-x64/claude"
echo "claude-code: fetching $version to compute its hash..."
hash=$(nix store prefetch-file --json "$url" | jq -r .hash)

jq -n --arg v "$version" --arg h "$hash" '{version: $v, hash: $h}' > sources.json
echo "claude-code: $current -> $version"
