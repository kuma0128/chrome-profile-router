#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--universal" ) ]]; then
    printf 'Usage: %s [--universal]\n' "$0" >&2
    exit 1
fi
app_dir="$project_dir/dist/Chrome Profile Router.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$app_dir/Contents/Frameworks"
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
    sparkle_dir="$project_dir/.build/universal-arm64/artifacts/sparkle/Sparkle"
else
    xcrun swift build -c release
    bin_dir="$(xcrun swift build -c release --show-bin-path)"
    cp "$bin_dir/ChromeProfileRouter" "$app_dir/Contents/MacOS/ChromeProfileRouter"
    sparkle_dir="$project_dir/.build/artifacts/sparkle/Sparkle"
fi
ditto "$sparkle_dir/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$app_dir/Contents/Frameworks/Sparkle.framework"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp config.json "$app_dir/Contents/Resources/config.json"
for localization in Resources/*.lproj; do
    plutil -lint "$localization/Localizable.strings"
    ditto "$localization" "$app_dir/Contents/Resources/$(basename "$localization")"
done
# Remove debug symbols, including local source paths, from the distributable binary.
xcrun strip -S "$app_dir/Contents/MacOS/ChromeProfileRouter"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
printf 'Built: %s\n' "$app_dir"
