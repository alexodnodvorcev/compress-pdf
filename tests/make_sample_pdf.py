#!/usr/bin/env python3
"""Generate a small, deliberately uncompressed PDF used as a test fixture.

The page contains text, vector graphics and a raw RGB raster image.  Because
nothing is compressed, Ghostscript-based compression has plenty of room to
shrink it, while a lossless pipeline must reproduce the rendered page exactly.
"""
import sys


WIDTH = 200
HEIGHT = 200

# Raw (uncompressed) RGB raster with smooth gradients and noise so that any
# downsampling or lossy re-encoding becomes visible when the page is rendered.
raw_image = bytearray()
for y in range(HEIGHT):
    for x in range(WIDTH):
        raw_image.append((x * 255) // WIDTH)
        raw_image.append((y * 255) // HEIGHT)
        raw_image.append((x ^ y) & 0xFF)
raw_image = bytes(raw_image)

content = (
    b"q\n"
    b"0 0 0 rg\n"
    b"BT /F1 14 Tf 20 370 Td (Lossless compression test) Tj ET\n"
    b"0.1 0.2 0.7 rg 20 20 360 50 re f\n"
    b"q 200 0 0 200 100 100 cm /Im0 Do Q\n"
    b"Q\n"
)

objects = {
    1: b"<< /Type /Catalog /Pages 2 0 R >>",
    2: b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    3: (
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 400] "
        b"/Resources << /Font << /F1 6 0 R >> /XObject << /Im0 5 0 R >> >> "
        b"/Contents 4 0 R >>"
    ),
    4: b"<< /Length %d >>\nstream\n" % len(content) + content + b"endstream",
    5: (
        b"<< /Type /XObject /Subtype /Image /Width %d /Height %d "
        b"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Length %d >>\nstream\n"
        % (WIDTH, HEIGHT, len(raw_image))
    )
    + raw_image
    + b"\nendstream",
    6: b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
}


def build_pdf():
    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = {}
    for number in sorted(objects):
        offsets[number] = len(out)
        out += b"%d 0 obj\n" % number + objects[number] + b"\nendobj\n"

    xref_pos = len(out)
    out += b"xref\n0 %d\n" % (len(objects) + 1)
    out += b"0000000000 65535 f \n"
    for number in sorted(objects):
        out += b"%010d 00000 n \n" % offsets[number]
    out += (
        b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
        % (len(objects) + 1, xref_pos)
    )
    return bytes(out)


def main():
    if len(sys.argv) != 2:
        print("usage: make_sample_pdf.py <output.pdf>", file=sys.stderr)
        return 2
    with open(sys.argv[1], "wb") as handle:
        handle.write(build_pdf())
    return 0


if __name__ == "__main__":
    sys.exit(main())
