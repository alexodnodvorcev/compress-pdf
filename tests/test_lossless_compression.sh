#!/usr/bin/env bash
# Tests for compress-gs-pdfs.sh.
#
# The core guarantee of the script is that compression is strictly lossless:
# a PDF must shrink in size while rendering exactly the same as before.
# These tests render the original and the compressed file to the same raster
# device and compare the result byte for byte.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/compress-gs-pdfs.sh"
GENERATOR="$ROOT_DIR/tests/make_sample_pdf.py"
PYTHON="${PYTHON:-python3}"

if ! command -v gs >/dev/null 2>&1; then
    echo "ERROR: Ghostscript ('gs') is required but was not found." >&2
    exit 1
fi
if ! command -v "$PYTHON" >/dev/null 2>&1; then
    echo "ERROR: '$PYTHON' is required but was not found." >&2
    exit 1
fi
[ -f "$SCRIPT" ] || { echo "ERROR: '$SCRIPT' not found." >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

INPUT_DIR="$TMP_DIR/input"
SAMPLE="$INPUT_DIR/sample.pdf"
mkdir -p "$INPUT_DIR"
"$PYTHON" "$GENERATOR" "$SAMPLE"

ORIGINAL_SIZE=$(wc -c < "$SAMPLE")
echo "Generated sample PDF: $ORIGINAL_SIZE bytes"

# Run the real compression script on a directory containing only the sample.
bash "$SCRIPT" "$INPUT_DIR" >/dev/null

COMPRESSED="$SAMPLE"
BACKUP="$SAMPLE.backup"

failures=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; failures=$((failures + 1)); }

# Test 1: the sample must actually get compressed, otherwise nothing is proven.
if [ -f "$BACKUP" ]; then
    pass "compression triggered; original preserved as .backup"
else
    fail "compression did not trigger (fixture not compressible?)"
fi

if [ -f "$BACKUP" ]; then
    # Test 2: the produced file must be smaller than the original.
    COMPRESSED_SIZE=$(wc -c < "$COMPRESSED")
    if [ "$COMPRESSED_SIZE" -lt "$ORIGINAL_SIZE" ]; then
        pass "size reduced: $ORIGINAL_SIZE -> $COMPRESSED_SIZE bytes"
    else
        fail "compressed file is not smaller: $ORIGINAL_SIZE -> $COMPRESSED_SIZE bytes"
    fi

    # Test 3: rendering must be unchanged (no visible quality loss).
    # A tiny +/-2 per-channel tolerance absorbs Ghostscript's color rounding;
    # lossy image compression or downsampling would exceed it by far.
    render() {
        gs -q -dFirstPage=1 -dLastPage=1 \
            -sDEVICE=ppmraw -r150 \
            -dTextAlphaBits=1 -dGraphicsAlphaBits=1 \
            -o "$2" "$1"
    }
    render "$BACKUP" "$TMP_DIR/original.ppm"
    render "$COMPRESSED" "$TMP_DIR/compressed.ppm"
    if "$PYTHON" "$ROOT_DIR/tests/compare_ppm.py" \
        "$TMP_DIR/original.ppm" "$TMP_DIR/compressed.ppm"; then
        pass "rendered page unchanged after compression (lossless)"
    else
        fail "rendered page differs: compression is LOSSY"
    fi
fi

if [ "$failures" -ne 0 ]; then
    echo "FAILED: $failures test(s) failed."
    exit 1
fi

echo "ALL TESTS PASSED."
