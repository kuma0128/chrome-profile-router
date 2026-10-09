#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
app_dir="$project_dir/dist/Chrome Profile Router.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/ChromeProfileRouter" "$app_dir/Contents/MacOS/ChromeProfileRouter"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp config.json "$app_dir/Contents/Resources/config.json"
# Remove debug symbols, including local source paths, from the distributable binary.
xcrun strip -S "$app_dir/Contents/MacOS/ChromeProfileRouter"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
printf 'Built: %s\n' "$app_dir"
