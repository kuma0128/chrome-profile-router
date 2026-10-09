#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build.sh"
app_dir="$HOME/Applications/Chrome Profile Router.app"
mkdir -p "$HOME/Applications"
# Let the app create missing settings, and validate them before replacing an installed app.
"$project_dir/dist/Chrome Profile Router.app/Contents/MacOS/ChromeProfileRouter" --check-config
if [[ -e "$app_dir" ]]; then
    backup_dir="$(mktemp -d "$HOME/Applications/.chrome-profile-router-backup.XXXXXX")"
    mv "$app_dir" "$backup_dir/"
    printf 'Previous app: %s\n' "$backup_dir/Chrome Profile Router.app"
fi
ditto "$project_dir/dist/Chrome Profile Router.app" "$app_dir"
codesign --verify --strict "$app_dir"
"/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" -f "$app_dir"
printf 'Installed: %s\n' "$app_dir"
printf '既定ブラウザは、システム設定 → デスクトップとDock → デフォルトのWebブラウザから変更できます。\n'
