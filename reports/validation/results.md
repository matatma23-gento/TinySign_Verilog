# RTL validation results

Suite: full. Source: simulation. Board: NOT RUN.

| Test | Result | Wall time (s) |
|---|---|---:|
| python_reference | PASS | 0.132 |
| python_vs_verilog_mod_arith | FAIL | 0.036 |
| tb_montgomery_mul | FAIL | 0.036 |
| tb_mod_arith | FAIL | 0.005 |
| tb_point_ops | FAIL | 0.004 |
| tb_scalar_mult | FAIL | 0.004 |
| tb_hmac | FAIL | 0.004 |
| tb_rfc6979 | FAIL | 0.005 |
| tb_sha256_hash | FAIL | 0.004 |
| tb_ecdsa_signer | FAIL | 0.004 |
| tb_key_manager | FAIL | 0.004 |
| tb_tinysign_core | FAIL | 0.005 |
| tb_tinysign_de10nano | FAIL | 0.004 |
| tb_selftest_uart | FAIL | 0.005 |
| tb_board_selftest | FAIL | 0.006 |

Wall time is host simulation runtime, not FPGA latency. See per-test logs for cycle counts.
