"""Independent Python reference model for ECDSA over NIST P-256.

Parameters follow NIST SP 800-186, section 4.2.1.3. RFC 6979 nonces use
HMAC-SHA-256 as specified in RFC 6979.
"""
from __future__ import annotations

import hashlib
import hmac
from typing import Iterator, Optional, Tuple

P = int("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF", 16)
N = int("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551", 16)
A = P - 3
B = int("5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B", 16)
GX = int("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296", 16)
GY = int("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5", 16)
G = (GX, GY)
Point = Optional[Tuple[int, int]]


def inverse(value: int, modulus: int) -> int:
    """Return the modular inverse; reject zero and noninvertible values."""
    value %= modulus
    if value == 0:
        raise ZeroDivisionError("zero has no modular inverse")
    return pow(value, -1, modulus)


def point_is_on_curve(point: Point) -> bool:
    if point is None:
        return True
    x, y = point
    if not (0 <= x < P and 0 <= y < P):
        return False
    return (y * y - (x * x * x + A * x + B)) % P == 0


def point_add(left: Point, right: Point) -> Point:
    if left is None:
        return right
    if right is None:
        return left
    x1, y1 = left
    x2, y2 = right
    if not point_is_on_curve(left) or not point_is_on_curve(right):
        raise ValueError("point is not on P-256")
    if x1 == x2:
        if (y1 + y2) % P == 0:
            return None
        slope = ((3 * x1 * x1 + A) * inverse(2 * y1, P)) % P
    else:
        slope = ((y2 - y1) * inverse(x2 - x1, P)) % P
    x3 = (slope * slope - x1 - x2) % P
    y3 = (slope * (x1 - x3) - y1) % P
    return (x3, y3)


def scalar_mult(scalar: int, point: Point = G) -> Point:
    if scalar < 0:
        raise ValueError("scalar must be nonnegative")
    if point is not None and not point_is_on_curve(point):
        raise ValueError("point is not on P-256")
    result: Point = None
    addend = point
    while scalar:
        if scalar & 1:
            result = point_add(result, addend)
        addend = point_add(addend, addend)
        scalar >>= 1
    return result


def jacobian_double(point: Tuple[int, int, int]) -> Tuple[int, int, int]:
    """Double a P-256 Jacobian point using the a=-3 formula."""
    x, y, z = point
    if z % P == 0 or y % P == 0:
        return (0, 1, 0)
    delta = z * z % P
    gamma = y * y % P
    beta = x * gamma % P
    alpha = 3 * (x - delta) * (x + delta) % P
    x3 = (alpha * alpha - 8 * beta) % P
    y3 = (alpha * (4 * beta - x3) - 8 * gamma * gamma) % P
    z3 = 2 * y * z % P
    return x3, y3, z3


def jacobian_add(left: Tuple[int, int, int], right: Tuple[int, int, int]) -> Tuple[int, int, int]:
    """Add general Jacobian P-256 points; infinity is represented by Z=0."""
    x1, y1, z1 = left
    x2, y2, z2 = right
    if z1 % P == 0:
        return right
    if z2 % P == 0:
        return left
    z1z1 = z1 * z1 % P
    z2z2 = z2 * z2 % P
    u1 = x1 * z2z2 % P
    u2 = x2 * z1z1 % P
    s1 = y1 * z2 * z2z2 % P
    s2 = y2 * z1 * z1z1 % P
    h = (u2 - u1) % P
    r = (s2 - s1) % P
    if h == 0:
        return jacobian_double(left) if r == 0 else (0, 1, 0)
    hh = h * h % P
    hhh = h * hh % P
    v = u1 * hh % P
    x3 = (r * r - hhh - 2 * v) % P
    y3 = (r * (v - x3) - s1 * hhh) % P
    z3 = z1 * z2 * h % P
    return x3, y3, z3


def jacobian_to_affine(point: Tuple[int, int, int]) -> Point:
    x, y, z = point
    if z % P == 0:
        return None
    z_inv = inverse(z, P)
    z2 = z_inv * z_inv % P
    return (x * z2 % P, y * z2 * z_inv % P)


def public_key(private_key: int) -> Tuple[int, int]:
    if not 1 <= private_key < N:
        raise ValueError("private key must satisfy 1 <= d < n")
    point = scalar_mult(private_key, G)
    assert point is not None
    return point


def bits2int(data: bytes, qlen: int = N.bit_length()) -> int:
    value = int.from_bytes(data, "big")
    excess = len(data) * 8 - qlen
    return value >> excess if excess > 0 else value


def int2octets(value: int, rolen: int = (N.bit_length() + 7) // 8) -> bytes:
    if value < 0 or value >= (1 << (8 * rolen)):
        raise ValueError("integer does not fit the requested octet length")
    return value.to_bytes(rolen, "big")


def bits2octets(data: bytes) -> bytes:
    z1 = bits2int(data)
    z2 = z1 - N if z1 >= N else z1
    return int2octets(z2)


def deterministic_nonces(private_key: int, digest: bytes) -> Iterator[int]:
    """Yield RFC 6979 candidate nonces for P-256 and SHA-256."""
    if not 1 <= private_key < N:
        raise ValueError("private key must satisfy 1 <= d < n")
    if len(digest) != 32:
        raise ValueError("digest must be exactly 32 bytes")
    holen = hashlib.sha256().digest_size
    rolen = (N.bit_length() + 7) // 8
    bx = int2octets(private_key, rolen) + bits2octets(digest)
    v = b"\x01" * holen
    k_state = b"\x00" * holen
    k_state = hmac.new(k_state, v + b"\x00" + bx, hashlib.sha256).digest()
    v = hmac.new(k_state, v, hashlib.sha256).digest()
    k_state = hmac.new(k_state, v + b"\x01" + bx, hashlib.sha256).digest()
    v = hmac.new(k_state, v, hashlib.sha256).digest()
    while True:
        candidate_bytes = b""
        while len(candidate_bytes) < rolen:
            v = hmac.new(k_state, v, hashlib.sha256).digest()
            candidate_bytes += v
        candidate = bits2int(candidate_bytes)
        if 1 <= candidate < N:
            yield candidate
        k_state = hmac.new(k_state, v + b"\x00", hashlib.sha256).digest()
        v = hmac.new(k_state, v, hashlib.sha256).digest()


def sign_digest(private_key: int, digest: bytes) -> Tuple[int, int]:
    if not 1 <= private_key < N:
        raise ValueError("private key must satisfy 1 <= d < n")
    if len(digest) != 32:
        raise ValueError("digest must be exactly 32 bytes")
    z = bits2int(digest)
    for nonce in deterministic_nonces(private_key, digest):
        point = scalar_mult(nonce, G)
        assert point is not None
        r = point[0] % N
        if r == 0:
            continue
        s = (inverse(nonce, N) * (z + r * private_key)) % N
        if s != 0:
            return r, s
    raise RuntimeError("unreachable nonce exhaustion")


def verify_digest(public_point: Point, signature: Tuple[int, int], digest: bytes) -> bool:
    if len(digest) != 32 or public_point is None or not point_is_on_curve(public_point):
        return False
    r, s = signature
    if not (1 <= r < N and 1 <= s < N):
        return False
    z = bits2int(digest)
    w = inverse(s, N)
    u1 = (z * w) % N
    u2 = (r * w) % N
    result = point_add(scalar_mult(u1, G), scalar_mult(u2, public_point))
    return result is not None and (result[0] % N) == r
