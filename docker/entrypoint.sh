#!/bin/bash
set -e

INPUT="$1"
OUTPUT_DIR="${2:-/output}"

if [ -z "$INPUT" ]; then
    echo "Usage: docker run --rm -v /host/dir:/data audio-lifter-omnizart /data/audio.wav /data" >&2
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: input file not found inside container: $INPUT" >&2
    echo "Make sure the host directory containing the file is mounted with -v." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
exec omnizart drum transcribe "$INPUT" -o "$OUTPUT_DIR"
