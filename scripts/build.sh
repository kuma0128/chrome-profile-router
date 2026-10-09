#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--universal" ) ]]; then
    printf 'Usage: %s [--universal]\n' "$0" >&2
    exit 1
fi
app_dir="$project_dir/dist/Chrome Profile Router.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
if [[ "${1:-}" == "--universal" ]]; then
    binaries=()
    for architecture in arm64 x86_64; do
        triple="$architecture-apple-macosx13.0"
        build_args=(-c release --triple "$triple" --scratch-path ".build/universal-$architecture")
        xcrun swift build "${build_args[@]}"
        bin_dir="$(xcrun swift build "${build_args[@]}" --show-bin-path)"
        binaries+=("$bin_dir/ChromeProfileRouter")
    done
    xcrun lipo -create "${binaries[@]}" -output "$app_dir/Contents/MacOS/ChromeProfileRouter"
else
    xcrun swift build -c release
    bin_dir="$(xcrun swift build -c release --show-bin-path)"
    cp "$bin_dir/ChromeProfileRouter" "$app_dir/Contents/MacOS/ChromeProfileRouter"
fi
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp config.json "$app_dir/Contents/Resources/config.json"
# Remove debug symbols, including local source paths, from the distributable binary.
xcrun strip -S "$app_dir/Contents/MacOS/ChromeProfileRouter"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
printf 'Built: %s\n' "$app_dir"
