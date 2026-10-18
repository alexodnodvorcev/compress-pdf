#!/usr/bin/env python3
"""Compare two binary PPM (P6) images pixel by pixel.

Exits 0 when every channel differs by at most MAX_DELTA, otherwise exits 1.

Ghostscript occasionally rounds vector color operands by +/-1 LSB when it
rewrites a PDF (e.g. ``0.1 0.2 0.7 rg`` becomes
``0.100098 0.199951 0.699219 rg``), which is imperceptible.  Lossy image
compression (JPEG) or image downsampling, in contrast, produces deviations of
tens of levels, so a small tolerance still catches any real quality loss.
"""
import sys

MAX_DELTA = 2


def read_ppm(path):
    with open(path, "rb") as handle:
        magic = handle.readline().strip()
        if magic != b"P6":
            raise ValueError("not a binary PPM (P6) file: %s" % path)
        line = handle.readline()
        while line.startswith(b"#"):
            line = handle.readline()
        width, height = (int(value) for value in line.split())
        maxval = int(handle.readline())
        if maxval != 255:
            raise ValueError("only 8-bit PPM is supported: %s" % path)
        data = handle.read()
        if len(data) != width * height * 3:
            raise ValueError("unexpected pixel data length in %s" % path)
        return data


def main():
    if len(sys.argv) != 3:
        print("usage: compare_ppm.py <a.ppm> <b.ppm>", file=sys.stderr)
        return 2

    first = read_ppm(sys.argv[1])
    second = read_ppm(sys.argv[2])
    if len(first) != len(second):
        print("FAIL: images have different dimensions")
        return 1

    max_delta = 0
    over_tolerance = 0
    for left, right in zip(first, second):
        delta = abs(left - right)
        if delta > max_delta:
            max_delta = delta
        if delta > MAX_DELTA:
            over_tolerance += 1

    if max_delta == 0:
        print("rendered page is bit-identical")
        return 0

    print("max per-channel delta: %d, channels over tolerance: %d" % (max_delta, over_tolerance))
    if over_tolerance:
        print("FAIL: compression changed the rendered page (lossy)")
        return 1

    print("within +/-%d tolerance: page is visually lossless" % MAX_DELTA)
    return 0


if __name__ == "__main__":
    sys.exit(main())
