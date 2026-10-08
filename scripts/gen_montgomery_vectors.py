#!/usr/bin/env python3
"""Generate independent big-integer oracles; no RTL algorithm is duplicated."""
import argparse
import random
from pathlib import Path


def vectors(width):
    radix = 1 << width
    rng = random.Random(0x54494E59 + width)
    if width <= 5:
        for modulus in range(3, radix, 2):
            for a in range(modulus):
                for b in range(modulus):
                    yield a, b, modulus
        return
    moduli = [3, 15, radix // 2 + 1, radix - 1]
    if width == 256:
        moduli += [
            0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF,
            0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551,
        ]
    for modulus in moduli:
        for a in (0, 1, modulus // 2, modulus - 2, modulus - 1):
            for b in (0, 1, modulus // 2, modulus - 2, modulus - 1):
                yield a, b, modulus
        for _ in range(64):
            yield rng.randrange(modulus), rng.randrange(modulus), modulus
    for _ in range(64):
        modulus = rng.randrange(3, radix) | 1
        yield rng.randrange(modulus), rng.randrange(modulus), modulus


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--width', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.width < 2:
        parser.error('width must be at least 2')
    radix = 1 << args.width
    lines = []
    for a, b, modulus in vectors(args.width):
        raw = a * b * pow(radix, -1, modulus) % modulus
        ordinary = a * b % modulus
        packed = 0
        for value in (a, b, modulus, raw, ordinary):
            packed = (packed << args.width) | value
        lines.append(f'{packed:0{(5 * args.width + 3) // 4}x}\n')
    args.output.write_text(''.join(lines))
    print(len(lines))


if __name__ == '__main__':
    main()
