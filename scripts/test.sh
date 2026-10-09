#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
args=(--disable-xctest)
# Some Command Line Tools releases ship TestingMacros outside the default plugin search path.
toolchain_bin="$(dirname "$(xcrun --find swiftc)")"
testing_plugin="$toolchain_bin/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$testing_plugin" ]]; then
    args+=(-Xswiftc -load-plugin-library -Xswiftc "$testing_plugin")
fi
xcrun swift test "${args[@]}" "$@"
