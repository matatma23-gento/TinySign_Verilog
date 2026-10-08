#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
waves=0
if [[ "${1:-}" == --help ]]; then
  printf 'Usage: bash scripts/run_rtl_tests.sh [--waves] [tb_name ...]\n'
  printf 'No arguments: full regression. --waves alone: short 8-bit Montgomery demo.\n'
  exit 0
fi
if [[ "${1:-}" == --waves ]]; then
  waves=1
  shift
fi
build="$root/sim/iverilog/build"
mkdir -p "$build"
iverilog_bin="${IVERILOG:-iverilog}"
vvp_bin="${VVP:-vvp}"
compiler_args=(-g2001 -Wall)
# Optional support for a locally extracted Icarus package.
if [[ -n "${IVERILOG_BASE:-}" ]]; then
  compiler_args+=(-B "$IVERILOG_BASE")
fi
rtl=("$root"/rtl/*/*.v)
tests=(tb_montgomery_mul tb_mod_arith tb_point_ops tb_scalar_mult tb_hmac
       tb_rfc6979 tb_sha256_hash tb_ecdsa_signer tb_key_manager tb_tinysign_core tb_shared_engines tb_tinysign_de10nano)
if (( $# )); then tests=("$@"); fi
if (( waves && $# == 0 )); then tests=(tb_montgomery_wave); fi

run_simulation() {
  local stem="$1"
  shift
  local dump_args=()
  if (( waves )); then dump_args=("+wavefile=$build/$stem.vcd"); fi
  if [[ "$stem" == tb_board_selftest && -n "${TRACE_DIR:-}" ]]; then
    mkdir -p "$TRACE_DIR"
    dump_args+=("+trace=$TRACE_DIR/board_selftest_trace.csv")
  fi
  # -N makes Verilog $stop a failing process exit, without an interactive prompt.
  "$vvp_bin" -N "$build/$stem.vvp" "$@" "${dump_args[@]}"
  if (( waves )); then printf 'Waveform: %s\n' "$build/$stem.vcd"; fi
}

for test in "${tests[@]}"; do
  if [[ ! "$test" =~ ^tb_[a-z0-9_]+$ || ! -f "$root/tb/$test.v" ]]; then
    printf 'Unknown testbench: %s\n' "$test" >&2
    exit 1
  fi
  wave_args=()
  if (( waves )); then
    dump_source="$build/${test}_wave_dump.v"
    cat > "$dump_source" <<EOF
\`timescale 1ns/1ps
module tinysign_wave_dump;
  reg [4095:0] wavefile;
  initial begin
    if (!\$value\$plusargs("wavefile=%s", wavefile)) begin
      \$display("FAIL: missing waveform output path"); \$stop;
    end
    \$dumpfile(wavefile);
    \$dumpvars(0, $test);
  end
endmodule
EOF
    wave_args=(-s tinysign_wave_dump "$dump_source")
  fi
  if [[ "$test" == tb_montgomery_mul ]]; then
    for width in 2 5 8 17 256 513; do
      vectors="$build/montgomery_$width.hex"
      count="$(python3 "$root/scripts/gen_montgomery_vectors.py" --width "$width" --output "$vectors")"
      "$iverilog_bin" "${compiler_args[@]}" -s "$test" \
        -P "$test.WIDTH=$width" -P "$test.VECTOR_COUNT=$count" \
        -o "$build/${test}_$width.vvp" "${rtl[@]}" "$root/tb/$test.v" "${wave_args[@]}"
      run_simulation "${test}_$width" "+vectors=$vectors"
    done
  else
    "$iverilog_bin" "${compiler_args[@]}" -s "$test" \
      -o "$build/$test.vvp" "${rtl[@]}" "$root/tb/$test.v" "${wave_args[@]}"
    run_simulation "$test"
  fi
done
