# Host interface and register map

The proposed FPGA-facing interface is a 32-bit, word-aligned Avalon-MM slave for a DE10-Nano HPS/lightweight bridge wrapper. The crypto core remains independent of Avalon so pure RTL testbenches can drive it directly. Multiword values occupy eight 32-bit words in most-significant-word-first order.

## Registers

| Byte offset | Name | Access | Meaning |
|---:|---|---|---|
| `0x00` | `CMD` | W | Command code below |
| `0x04` | `STATUS` | R | Bit 0 READY, bit 1 BUSY, bit 2 DONE, bit 3 ERROR, bit 4 KEY_VALID, bit 5 KEY_LOCKED, bit 6 SIGN_VALID, bit 7 ZEROIZED |
| `0x08` | `ERROR_CODE` | R | Last command error; zero when no error is latched |
| `0x10-0x2C` | `KEY_D[0..7]` | W | Private scalar staging words; reads return zero |
| `0x30-0x4C` | `DIGEST[0..7]` | W | 256-bit SHA-256 digest input |
| `0x50-0x6C` | `PUB_X[0..7]` | R | Public key x coordinate |
| `0x70-0x8C` | `PUB_Y[0..7]` | R | Public key y coordinate |
| `0x90-0xAC` | `SIG_R[0..7]` | R | ECDSA signature component r |
| `0xB0-0xCC` | `SIG_S[0..7]` | R | ECDSA signature component s |

Unlisted addresses read as zero and writes set an error. `KEY_D` reads always return zero. Writes require all four byte enables; partial-word writes are rejected with an error. All multiword values use most-significant-word-first order. `KEY_D` staging tracks all eight written words and provisioning is rejected until the mask is complete.

## Commands

`CMD` is a one-shot write; unknown values set ERROR and do no cryptographic work.

| Value | Name | Preconditions and effect |
|---:|---|---|
| `0` | `NOP` | No effect |
| `1` | `PROVISION_KEY` | Require all key words written, key not already valid, and `1 <= d < n`; derive and store public key, then set KEY_VALID |
| `2` | `LOCK_KEY` | Require KEY_VALID; set KEY_LOCKED and reject further key writes |
| `3` | `GET_PUBLIC_KEY` | Require KEY_VALID; public key registers expose the previously derived public key |
| `4` | `SIGN_DIGEST` | Require KEY_VALID and KEY_LOCKED; sign the staged digest and publish `(r,s)` on success |
| `5` | `ZEROIZE` | Accepted even while BUSY; abort active signing, clear key and crypto intermediates, signature and digest state, and validity/lock flags; set ZEROIZED when clearing completes |
| `6` | `CLEAR_STATUS` | Clear DONE, ERROR, ERROR_CODE, SIGN_VALID, and ZEROIZED; does not alter the key lifecycle |

READY is high when no command is active. Commands and register writes issued while BUSY are rejected with an error, except ZEROIZE, which interrupts the active operation. Provisioning, locking, signing, and zeroization are serialized. Reset zeroizes volatile key and result state. No persistent key storage is claimed.
