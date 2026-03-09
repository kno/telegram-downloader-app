#!/usr/bin/env bash
#
# version.sh - Bump patch version and build number in pubspec.yaml
#
# Reads current version (MAJOR.MINOR.PATCH+BUILD), increments PATCH and BUILD,
# writes back to pubspec.yaml, and outputs the new version string.
#
set -euo pipefail

PUBSPEC="$(cd "$(dirname "$0")/.." && pwd)/pubspec.yaml"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "Error: pubspec.yaml not found at $PUBSPEC" >&2
  exit 1
fi

# Extract current version line
CURRENT=$(grep -E '^version:' "$PUBSPEC" | head -1 | awk '{print $2}')

if [[ -z "$CURRENT" ]]; then
  echo "Error: could not read version from pubspec.yaml" >&2
  exit 1
fi

# Parse components
SEMVER="${CURRENT%%+*}"
BUILD="${CURRENT##*+}"

MAJOR="${SEMVER%%.*}"
REST="${SEMVER#*.}"
MINOR="${REST%%.*}"
PATCH="${REST#*.}"

# Bump
NEW_PATCH=$((PATCH + 1))
NEW_BUILD=$((BUILD + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}+${NEW_BUILD}"

# Update pubspec.yaml in place (portable sed)
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"
else
  sed -i "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"
fi

# Output the semver portion (without build number) for use by CI
echo "${MAJOR}.${MINOR}.${NEW_PATCH}"
