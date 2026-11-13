#!/usr/bin/env bash
# Unit tests of the pure JavaScript modules: runs every tests/unit/*.test.mjs
# with node's test runner (each file passes when it exits without an error).
# Usage: config/quickshell/tests/unit.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
node --test "$here"/unit/*.test.mjs
