#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run-tagged-act.sh
# DESCRIPTION: Thin alias for act.sh --tagged (backward compatible).
# VERSION: 1.2.0
# EXIT_CODES/SIGNALS: Delegates to act.sh
# AUTHORS: Platform Team
# =============================================================================
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/act.sh" --tagged "$@"
