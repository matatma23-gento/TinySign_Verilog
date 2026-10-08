#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$root/scripts/run_rtl_tests.sh" tb_hmac tb_rfc6979
