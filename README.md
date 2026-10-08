# PURI-Sign: Protected Utility for Reliable Identity

PURI-Sign (previously TinySign) is a hardware security element prototype for protected-key ECDSA P-256 signing. It targets the Peruri Chip Hackathon 2026, Topik 1: Secure Identity & Security Element, with DE10-Nano / Cyclone V as the planned FPGA target.

The supplied proposal describes verification-only ECDSA; the current engineering handoff instead specifies signing with an internally held private key. This repository follows the handoff, and records the proposal mismatch in `docs/architecture.md`.

## PURI-Sign / DE10-Nano area refactor

The integrated core now shares its scalar, inverse, and affine/signature multiplier
between key provisioning and signing. ECDSA P-256 and RFC 6979 remain implemented.
The DE10-Nano device fit succeeds at 27,853 ALMs (Quartus logic utilization),
with 3,971 / 4,191 LABs occupied. The core requires a 25 MHz integration clock;
the original 50 MHz timing target was not met. Board pin/HPS integration is pending.
See [architecture, build, and validation notes](docs/puri_sign_area.md).
The isolated Quartus project is `quartus/puri_sign/TinySign.qpf`.

## Current status

- [x] Architecture, module hierarchy, register map, and implementation phases
- [x] Python P-256 reference model and RFC 6979 known-answer test
- [x] RTL modular arithmetic
- [x] Verilog-2001 RTL and testbenches; radix-2 Montgomery multiplication
- [x] RTL Jacobian point addition and doubling
- [x] RTL fixed-round scalar multiplication
- [x] RTL SHA-256, HMAC-SHA-256, and RFC 6979 nonce generation
- [x] RTL ECDSA P-256 signing controller
- [x] Protected key manager and key lifecycle
- [x] Register/security-element integration
- [x] DE10-Nano Avalon-MM shell and standalone Quartus self-test project
- [x] Quartus device fit for the shared core on 5CSEBA6U23I7
- [ ] Board clock/pin integration, complete I/O timing closure, programming, and physical-board capture

This is a prototype architecture. It does not claim resistance to physical tampering, power/EM side channels, or fault injection. Key state is volatile and cleared by reset/zeroization.

## Phase 1 reference tests

From this directory, run:

```sh
python3 -m unittest discover -s tests -v
```

The Python model uses only the standard library and includes P-256 point arithmetic, RFC 6979 HMAC-SHA-256 nonce derivation, digest signing, and signature verification. The registered RFC 6979 P-256/SHA-256 vector is used as a known-answer test.

## Verilog and Montgomery

Seluruh RTL dan testbench menggunakan **Verilog-2001** (`.v`). Script Icarus menggunakan `-g2001`, dan Quartus menggunakan `VERILOG_FILE`. Dependensi pengujian: Python 3.8+ dan Icarus Verilog (`iverilog`, `vvp`).

```sh
bash scripts/run_rtl_tests.sh
# Pengujian khusus Montgomery:
bash scripts/run_rtl_tests.sh tb_montgomery_mul
# Pengujian HMAC/RFC 6979:
bash scripts/run_nonce_tests.sh
```

`rtl/arithmetic/montgomery_mul.v` menghitung `a*b*R^-1 mod m`, dengan `R=2^WIDTH`. Modul `mod_mul.v` mengonversi operand terlebih dahulu sehingga hasil untuk pemanggil tetap `a*b mod m`. ECC, inversi modular, dan ECDSA otomatis menggunakan mesin ini. Modulus harus ganjil, minimal 3, dan operand harus lebih kecil dari modulus; inversi Fermat tetap memerlukan modulus prima.

Versi serial ini mengutamakan implementasi yang mudah diperiksa: pada 256 bit, Montgomery mentah membutuhkan 257 siklus dan perkalian biasa termasuk konversi membutuhkan 515 siklus. Perkalian lama membutuhkan 256 siklus. Slot operasi titik sekarang 14.000 siklus; perubahan ini **belum merupakan optimasi kecepatan atau bukti penghematan area**. Hasil area dan timing membutuhkan sintesis Quartus. Detail domain, handshake, dan batasan ada di [`docs/montgomery.md`](docs/montgomery.md).

## Architecture and interface

Untuk melihat timing diagram, jalankan `bash scripts/run_rtl_tests.sh --waves`, lalu buka `sim/iverilog/build/tb_montgomery_wave.vcd` dengan GTKWave. Contoh 8-bit ini memperlihatkan clock, reset, start, busy, done, hasil, dan error; jalur ECC utama tetap 256 bit. Panduan lengkap ada di [`docs/waveforms.md`](docs/waveforms.md).

See [`docs/architecture.md`](docs/architecture.md), [`docs/interface.md`](docs/interface.md), and [`docs/implementation_plan.md`](docs/implementation_plan.md). P-256 parameters are sourced from NIST SP 800-186; the deterministic signing vector is from RFC 6979 Appendix A.2.5.

Prosedur yang mengikuti format proposal untuk simulasi RTL, Yosys, dan uji board
ada di [`docs/proposal_testing.md`](docs/proposal_testing.md). Target board yang
didukung flow Quartus adalah DE10-Nano/Cyclone V; openXC7 hanya relevan untuk
target Xilinx 7-series.
