#!/bin/bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
    printf 'Usage: %s RELEASE.zip\n' "$0" >&2
    exit 1
fi
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
ditto -x -k "$1" "$check_dir"
app_dir="$check_dir/Chrome Profile Router.app"
router="$app_dir/Contents/MacOS/ChromeProfileRouter"
codesign --verify --strict --all-architectures "$app_dir"
architectures="$(xcrun lipo -archs "$router")"
for architecture in arm64 x86_64; do
    [[ " $architectures " == *" $architecture "* ]]
done
plutil -lint "$app_dir/Contents/Info.plist"
cmp "$project_dir/config.json" "$app_dir/Contents/Resources/config.json"

# Isolate Foundation's home directory so this check never touches real settings.
test_user_dir="$check_dir/user"
mkdir -p "$test_user_dir"
config="$test_user_dir/.config/chrome-profile-router/config.json"
CFFIXED_USER_HOME="$test_user_dir" "$router" --config "$project_dir/config.json" --check-config
test ! -e "$config"
# A normal launch with no URL must create settings and exit without opening Chrome.
CFFIXED_USER_HOME="$test_user_dir" "$router"
cmp "$project_dir/config.json" "$config"
CFFIXED_USER_HOME="$test_user_dir" "$router" --resolve 'https://work.example.com/' > "$check_dir/route.json"
test "$(plutil -extract 0.profileDirectory raw "$check_dir/route.json")" = 'Profile 1'
# Invalid user settings must be reported, never silently replaced by the sample.
printf 'invalid JSON\n' > "$config"
if CFFIXED_USER_HOME="$test_user_dir" "$router" --check-config > "$check_dir/invalid-settings.log" 2>&1; then
    printf 'Invalid settings were unexpectedly accepted.\n' >&2
    exit 1
fi
test "$(cat "$config")" = 'invalid JSON'
printf 'Package checks passed (%s).\n' "$(uname -m)"
