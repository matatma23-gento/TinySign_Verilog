#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
quartus_bin="${QUARTUS_SH:-quartus_sh}"
if ! command -v "$quartus_bin" >/dev/null 2>&1; then
  printf 'Quartus unavailable. Install Cyclone V device support or set QUARTUS_SH.\n' >&2
  exit 2
fi
cd "$root/quartus/selftest"
"$quartus_bin" --flow compile TinySignSelftest
printf 'Compile finished. Review Fitter and TimeQuest reports before programming.\n'
printf 'SOF: %s/quartus/selftest/output_files/TinySignSelftest.sof\n' "$root"
