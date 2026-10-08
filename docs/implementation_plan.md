# Implementation plan and milestone gates

Do not combine all cryptography into one RTL file. Each phase adds a Python oracle or directed RTL testbench and must pass its regression before the next phase begins.

| Phase | Deliverable | Gate |
|---:|---|---|
| 1 | Python P-256 constants, field/group operations, RFC 6979, ECDSA sign/verify, published known-answer vector | `python -m unittest discover -s tests -v` |
| 2 | RTL modular add/sub/mul/inverse for both `p` and `n` | PASS: Icarus boundaries for `p` and `n`; see `docs/verification.md` |
| 3 | RTL P-256 Jacobian point add/double, infinity and exceptional cases | PASS: G+G, G+2G, G+(-G), and 2G vector in Icarus |
| 4 | RTL fixed-256-round scalar multiplication and public-key derivation | PASS: `1G`, `2G`, `nG`, and RFC 6979 P-256 public key in Icarus |
| 5 | RTL SHA-256 compression, HMAC-SHA-256, RFC 6979 nonce generation | PASS: RFC 4231 HMAC, 97-byte HMAC, and RFC 6979 exact nonce vector |
| 6 | ECDSA P-256 signing controller | PASS: RFC 6979 signature vector and zero-key rejection; Python signature oracle agrees |
| 7 | Key manager, lock, reset, zeroization | PASS: no key readback interface, incomplete/range rejection, overwrite rejection, lock and zeroize |
| 8 | Register file, security controller, pure-core top | PASS: register-controlled provision, lock, signature, no-readback, and in-flight zeroize |
| 9 | DE10-Nano Avalon-MM wrapper and Quartus project skeleton | PARTIAL: Icarus shell regression passes; Quartus synthesis and board check are unverified because Quartus and hardware are unavailable |
| 10 | Measured benchmark reports and complete documentation | Not started: wait for Phase 9 synthesis/board verification; do not substitute estimates |

Use `p` for coordinate operations and `n` for scalar/signature operations in test names and expected values. Every RTL milestone should include a repeatable Python oracle comparison and simulator command. Run the Icarus RTL suite with `bash scripts/run_rtl_tests.sh` on a host with Python 3 and Icarus installed. RTL and testbenches now target Verilog-2001, including Montgomery modular multiplication; see `docs/montgomery.md`. Quartus and DE10-Nano hardware are not available in this environment.

## Exact Phase 1 command

```sh
python -m unittest discover -s tests -v
```
