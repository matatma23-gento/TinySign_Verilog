# TinySign architecture

## Project scope and source alignment

TinySign is a protected-key ECDSA P-256 signing element for Topik 1, Secure Identity & Security Element. It accepts a 32-byte SHA-256 digest and returns an ECDSA `(r,s)` signature. The private scalar is provisioned through a write-only path, retained in volatile internal state, and never exposed through register readback. The public key may be read.

The supplied `[PR4]Proposal_TinySign_PERURI_2026_Competition_Style.pdf` describes verification-only ECDSA, public-key inputs, and compatibility with the TT07 SHA-256 one-round interface. The later `TinySign_CODEX_MASTER_HANDOFF.md` instead defines protected-key signing as the final project. This implementation follows that signing handoff. Proposal text and estimates are not evidence of implemented behavior or measured PPA.

The digest-input interface is the first stable host mode. A SHA-256 compression engine is still needed internally for RFC 6979 HMAC-SHA-256 nonce derivation. Full arbitrary-message hashing may be added later as a separate front-end.

## Module hierarchy

```text
tinysign_de10nano (Avalon-MM shell; board integration pending)
└── tinysign_core (register decode, command FSM, status and data path)
    ├── key_manager (write-only staging, validation, dG controller, lock, zeroize)
    ├── ecdsa_signer (signing controller; internal clear resets sensitive state)
    │   ├── rfc6979 -> hmac_sha256 -> sha256_hash -> sha256_compress
    │   └── mod_add modulo n
    ├── u_shared_scalar -> point_ops -> modular arithmetic modulo p
    ├── u_shared_inverse (p for affine conversion; n for nonce inversion)
    └── u_shared_multiply (p for affine conversion; n for signing)
```

The command FSM assigns the shared engines exclusively to provisioning or signing.
Standalone key-manager and signer tests retain local engines by default; the integrated
core selects `SHARED_ENGINES=1`. See [PURI-Sign area refactor](puri_sign_area.md).

The pure `tinysign_core` register interface and command sequencing are implemented.
The shared Avalon-MM shell successfully fits 5CSEBA6U23I7 using 27,853 ALMs
(Quartus logic utilization) and 3,971 LABs. The isolated PURI-Sign project uses
a 25 MHz core clock constraint because the initial 50 MHz timing target failed.
Clock/pin integration and full board I/O timing closure remain Phase 9 work.

All RTL uses Verilog-2001. Modular multiplication uses `mod_mul -> montgomery_mul`, with conversion inside `mod_mul` so the rest of the design retains ordinary residues. Both field `p` and subgroup `n` operations use this path. See [`montgomery.md`](montgomery.md) for modulus restrictions and conversion costs. Scalar operation slots are now 14,000 clocks.

The initial RTL architecture is serialized and resource-shared. Field coordinates always use the P-256 field prime `p`; private keys, deterministic nonces, `r`, and `s` always use the subgroup order `n`. Separate modulus selection and verification boundaries are required so an operation cannot accidentally use the wrong modulus. Point arithmetic uses Jacobian coordinates and must implement the P-256 curve coefficient `a = -3`, including exceptional point cases.

Scalar multiplication processes a fixed 256-bit scalar schedule. Secret-dependent power/EM leakage and fault injection are outside this prototype's claimed protections and must not be implied to be solved by a fixed cycle count.

## Security lifecycle

1. Host writes eight 32-bit words to the write-only `KEY_D` staging window.
2. `PROVISION_KEY` requires every word, checks `1 <= d < n`, and computes/stores `Q=dG` internally.
3. `LOCK_KEY` prevents further provisioning writes. Signing is accepted only for a valid, locked key.
4. Host writes a digest and issues `SIGN_DIGEST`; RFC 6979 derives a deterministic nonce internally, and only `(r,s)` is exposed.
5. `ZEROIZE` clears the private key, derived public key, signature, and crypto intermediates. Reset also clears volatile key state.

This is FPGA register-level readback protection. It does not prevent privileged host software from observing the provisioning bus, power/EM analysis, or invasive silicon access. Any command source attached to the bus can request signing once the key is locked; host identity/authorization is not implemented in this initial interface.

## Reference assessment

| Supplied item | Reusable concept | Incompatible or unavailable |
|---|---|---|
| `fpga_secp256k1_verilog-main` | Serial/shared arithmetic, FSM sequencing, point-operation decomposition | secp256k1 constants, `a=0` formulas/reduction, and some documented input assumptions are not P-256. No repository LICENSE was supplied; use as architectural reference only. |
| `ecdsa-bls12381-zynq-accelerator-main` | HW/SW control partition, test-vector generation, arithmetic sequencing | 381-bit BLS12-381 verification, curve `a=0`, and Zynq AXI/DMA. No repository LICENSE was supplied; do not copy RTL. |
| `tt07-sha256-main` project 0718 | SHA-256 round behavior and Tiny Tapeout pin/register-bus conventions | It exposes a one-round, byte-addressed interface, not a full message hash or HMAC/RFC 6979 engine. Apache-2.0; any future source adaptation needs license and attribution notices. |
| `tt07-makerchip-template-main` | Tiny Tapeout build/test workflow conventions | Generic TL-Verilog template, not crypto RTL. Apache-2.0. |
| `ECC-main` and `ECC-Test Wokwi` | Tiny Tapeout/Wokwi integration example | Its own docs describe a 1-bit error-correcting transmission design (Hamming-style), despite “ECC” in the name. It is not elliptic-curve crypto. |
| Peruri guide and TT07 datasheet | Competition requirements and baseline catalog | Context/documentation only, not implementation components. Datasheet entries for PUF and 8-bit Xorshift do not make them part of TinySign; neither is used for nonces. |

No supplied repository provides P-256 signing RTL that is directly reusable. The Python model in this project is independently written as a mathematical reference.

## P-256 parameters

Use NIST SP 800-186, section 4.2.1.3, as the authoritative source for `p`, `n`, `a=-3`, `b`, and generator `G`. Keep field and scalar parameters separately named in both RTL and software.
