#!/bin/bash
# Backward-compatible FreeSign build entry point.
# Delegates to the maintained unsigned IPA builder and is safe to run from any
# working directory.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/build_unsigned_ipa.sh" "$@"
