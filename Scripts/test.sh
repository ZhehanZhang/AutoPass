#!/bin/bash
# Runs the unit tests. With only the Command Line Tools installed, SwiftPM sometimes fails to find the
# Swift Testing macro plugin; pass its path explicitly when it exists.
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [ -d "$PLUGINS" ]; then
    exec swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
fi
exec swift test "$@"
