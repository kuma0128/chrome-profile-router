#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
./scripts/build.sh --universal
app_dir="$project_dir/dist/Chrome Profile Router.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")"
archive="Chrome-Profile-Router-$version-universal.zip"
ditto -c -k --keepParent --norsrc "$app_dir" "$project_dir/dist/$archive"
cd dist
shasum -a 256 "$archive" > "$archive.sha256"
printf 'Packaged: %s\n' "$project_dir/dist/$archive"
