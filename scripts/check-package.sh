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
codesign --verify --deep --strict --all-architectures "$app_dir"
test -f "$app_dir/Contents/Frameworks/Sparkle.framework/Sparkle"
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
DYLD_PRINT_LIBRARIES=1 CFFIXED_USER_HOME="$test_user_dir" "$router" \
    --config "$project_dir/config.json" --check-config 2> "$check_dir/loaded-libraries.log"
# Verify the distributed app uses its own framework, not the developer's build directory.
grep -Fq "$app_dir/Contents/Frameworks/Sparkle.framework/" "$check_dir/loaded-libraries.log"
test ! -e "$config"
# CLI validation must create settings without displaying management or update UI.
CFFIXED_USER_HOME="$test_user_dir" "$router" --check-config
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
# Exercise Foundation's real language selection in the packaged app, with independent
# preferences per process. These launch arguments do not change the Mac's settings.
check_language() {
    local preferences="$1" region="$2" help_text="$3" error_text="$4"
    CFFIXED_USER_HOME="$test_user_dir" "$router" -AppleLanguages "$preferences" \
        -AppleLocale "$region" --help > "$check_dir/help.txt"
    grep -Fq "$help_text" "$check_dir/help.txt"
    if CFFIXED_USER_HOME="$test_user_dir" "$router" -AppleLanguages "$preferences" \
        -AppleLocale "$region" --check-config > "$check_dir/error.txt" 2>&1; then
        printf 'Invalid settings were unexpectedly accepted.\n' >&2
        exit 1
    fi
    grep -Fq "$error_text" "$check_dir/error.txt"
    CFFIXED_USER_HOME="$test_user_dir" "$router" -AppleLanguages "$preferences" \
        -AppleLocale "$region" --config "$project_dir/config.json" \
        --resolve 'https://work.example.com/' > "$check_dir/localized-route.json"
    cmp "$check_dir/route.json" "$check_dir/localized-route.json"
}
for preferences in '(ja)' '(ja-JP)' '(ja, en)' '(sw, ja, en)'; do
    check_language "$preferences" en_US '設定ファイルを検証' 'JSONの形式または必須項目に誤りがあります。'
done
for preferences in '(en)' '(en-GB)' '(en, ja)' '(sw)'; do
    check_language "$preferences" ja_JP 'Validate settings' 'The JSON format or required fields are invalid.'
done
while IFS='|' read -r language help_text error_text; do
    check_language "($language)" en_US "$help_text" "$error_text"
done <<'LANGUAGES'
de|Einstellungen prüfen|Das JSON-Format oder die Pflichtfelder sind ungültig.
fr|Vérifier les réglages|Le format JSON ou les champs obligatoires sont incorrects.
es|Validar los ajustes|El formato JSON o los campos obligatorios no son válidos.
es-MX|Validar los ajustes|El formato JSON o los campos obligatorios no son válidos.
it|Verifica le impostazioni|Il formato JSON o i campi obbligatori non sono validi.
pt-BR|Validar os ajustes|O formato JSON ou os campos obrigatórios são inválidos.
pt-PT|Validar as definições|O formato JSON ou os campos obrigatórios são inválidos.
ko|설정 검증|JSON 형식 또는 필수 항목이 올바르지 않습니다.
zh-Hans|验证设置|JSON 格式或必填字段有误。
zh-CN|验证设置|JSON 格式或必填字段有误。
zh-Hant|驗證設定|JSON 格式或必填欄位有誤。
zh-TW|驗證設定|JSON 格式或必填欄位有誤。
zh-HK|驗證設定|JSON 格式或必填欄位有誤。
ru|Проверить настройки|Неверный формат JSON или обязательные поля.
ar|التحقق من الإعدادات|تنسيق JSON أو الحقول المطلوبة غير صالحة.
LANGUAGES
printf 'Package checks passed (%s).\n' "$(uname -m)"
