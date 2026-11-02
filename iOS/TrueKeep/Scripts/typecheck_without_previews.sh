#!/bin/zsh
# Diagnostic fallback for environments that cannot start Simulator or Preview macros.
# This checks Swift types only. It does NOT build an app or execute XCTest.
set -euo pipefail
task_repo_root="${0:A:h:h:h:h}"
task_output_dir="$(mktemp -d "${TMPDIR:-/tmp/}truekeep-typecheck.XXXXXX")"
task_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
task_platform="$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer"
mkdir -p "$task_output_dir/sources" "$task_output_dir/modules"

# All repository Preview declarations are at the end of their source file.
for source in $(rg --files "$task_repo_root/iOS/TrueKeep/TrueKeep" -g '*.swift'); do
    awk '/^#Preview/{exit} {print}' "$source" > "$task_output_dir/sources/${source:t}"
done
xcrun swiftc -emit-module -enable-testing -swift-version 6 \
    -target arm64-apple-ios18.0 -sdk "$task_sdk" \
    -module-cache-path "$task_output_dir/modules" -module-name TrueKeep \
    -emit-module-path "$task_output_dir/TrueKeep.swiftmodule" "$task_output_dir/sources/"*.swift
echo 'PASS: app Swift types (Preview-only declarations excluded)'

for target in TrueKeepTests TrueKeepUITests; do
    xcrun swiftc -typecheck -swift-version 6 -target arm64-apple-ios18.0 \
        -sdk "$task_sdk" -module-cache-path "$task_output_dir/modules" \
        -I "$task_output_dir" -I "$task_platform/usr/lib" \
        -F "$task_platform/Library/Frameworks" \
        $(rg --files "$task_repo_root/iOS/TrueKeep/$target" -g '*.swift')
    echo "PASS: $target Swift types (tests not executed)"
done
echo "Diagnostic artifacts: $task_output_dir"
