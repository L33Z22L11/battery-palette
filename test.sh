#!/bin/zsh
set -eu
cd "${0:A:h}"
export DEVELOPER_DIR=${DEVELOPER_DIR:-$(xcode-select -p)}
TEST_STAGE=$(mktemp -d "${TMPDIR:-/tmp/}BatteryPalette-tests.XXXXXX")
trap 'rm -rf "$TEST_STAGE"' EXIT
export CLANG_MODULE_CACHE_PATH="$TEST_STAGE/ModuleCache"
xcrun swiftc Sources/StatusAppearance.swift Tests/StatusAppearanceTests.swift -framework AppKit -o "$TEST_STAGE/status-tests"
"$TEST_STAGE/status-tests"
xcrun swiftc Sources/BatteryData.swift Sources/SnapshotStore.swift Tests/SnapshotCompatibilityTests.swift -framework IOKit -o "$TEST_STAGE/snapshot-tests"
"$TEST_STAGE/snapshot-tests"

xcrun swiftc Sources/WidgetRegistrationHealth.swift Tests/WidgetRegistrationTests.swift -o "$TEST_STAGE/registration-tests"
"$TEST_STAGE/registration-tests"
