#!/usr/bin/env bash
# Point sources.json at a Claude Code release, using the version pointer and
# per-platform SHA-256 checksums Anthropic publishes. Needs curl and jq.
#
#   ./update.sh            # newest release (Anthropic's "latest" channel)
#   ./update.sh stable     # Anthropic's "stable" channel
#   ./update.sh 2.1.300    # an exact version
set -euo pipefail

base=https://downloads.claude.ai/claude-code-releases
platforms='["linux-x64","linux-arm64","darwin-x64","darwin-arm64"]'
target=${1:-latest}

case "$target" in
  latest | stable) version=$(curl -fsSL "$base/$target") ;;
  *) version=$target ;;
esac
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Unexpected version %q\n' "$version" >&2
  exit 1
fi

manifest=$(curl -fsSL "$base/$version/manifest.json")

cd "$(dirname "$0")"
jq --arg base "$base" --arg version "$version" --argjson platforms "$platforms" '
  . as $manifest
  | if .version != $version then error("manifest is for \(.version), not \($version)") else . end
  | {
      version,
      baseUrl: $base,
      platforms: ($platforms | map({ key: ., value: $manifest.platforms[.].checksum }) | from_entries)
    }
  | if all(.platforms[]; type == "string" and test("^[0-9a-f]{64}$")) then .
    else error("missing or malformed checksum in manifest") end
' <<<"$manifest" >sources.json.new
mv sources.json.new sources.json

printf 'sources.json -> Claude Code %s\n' "$version"
