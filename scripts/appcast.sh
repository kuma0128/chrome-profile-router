#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
archive="Chrome-Profile-Router-$version-universal.zip"
feed_dir="$(mktemp -d)"
trap 'rm -rf "$feed_dir"' EXIT
cp "dist/$archive" "$feed_dir/"
tool="$project_dir/.build/universal-arm64/artifacts/sparkle/Sparkle/bin/generate_appcast"
signing=(--account chrome-profile-router)
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    signing=(--ed-key-file -)
fi
# The secret is only sent on stdin, never as a command-line argument or a file.
printf '%s' "${SPARKLE_PRIVATE_KEY:-}" | "$tool" "${signing[@]}" \
    --maximum-deltas 0 \
    --download-url-prefix "https://github.com/kuma0128/chrome-profile-router/releases/download/v$version/" \
    --link "https://github.com/kuma0128/chrome-profile-router/releases/tag/v$version" \
    "$feed_dir"
cp "$feed_dir/appcast.xml" dist/appcast.xml
printf 'Signed update feed: %s/dist/appcast.xml\n' "$project_dir"
