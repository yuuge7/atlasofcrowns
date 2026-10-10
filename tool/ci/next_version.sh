#!/usr/bin/env bash
# Works out the version of the next release.
#
#   git ls-remote --tags --refs origin | sed 's#.*refs/tags/##' | tool/ci/next_version.sh [pubspec.yaml]
#
# Reads the existing tags from stdin, one per line, and prints three lines:
#
#   tag=v1.4      the git tag and the release name suffix
#   name=1.4      Android versionName
#   code=10004    Android versionCode, always higher than every earlier release
#
# The major number comes from `version:` in pubspec.yaml and is the only part
# set by hand. The minor is one more than the highest v<major>.<n> tag, or 0
# when the major has no release yet. Tags of other shapes are ignored.
set -euo pipefail

pubspec="${1:-pubspec.yaml}"
major=$(sed -nE 's/^version:[[:space:]]*([0-9]+)\..*/\1/p' "$pubspec" | head -n 1)
if [ -z "$major" ]; then
  echo "No 'version: <major>.<minor>...' line found in $pubspec" >&2
  exit 1
fi

last=$(grep -E "^v${major}\.[0-9]+$" | sed -E "s/^v${major}\.//" | sort -n | tail -n 1 || true)
if [ -z "$last" ]; then
  minor=0
else
  minor=$((10#$last + 1))
fi
if [ "$minor" -ge 10000 ]; then
  echo "v${major} has run out of minor numbers; raise the major in $pubspec" >&2
  exit 1
fi

echo "tag=v${major}.${minor}"
echo "name=${major}.${minor}"
echo "code=$((major * 10000 + minor))"
