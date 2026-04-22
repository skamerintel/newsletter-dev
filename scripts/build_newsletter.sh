#!/bin/bash
# build_newsletter.sh - Optimize images and embed as base64 in newsletter HTML
#
# Usage:
#   ./scripts/build_newsletter.sh <input.html> [output.html]
#
# This script:
#   1. Finds all images in output/ referenced by the HTML
#   2. Optimizes them (resize + convert to JPEG)
#   3. Replaces image URLs with base64 data URIs
#   4. Produces a self-contained HTML ready for copy-paste into Outlook
#
# Image sizing:
#   - Banner images (width="640"): resized to 640px
#   - Section icons (width="100"): resized to 200px (2x for retina)
#   - All converted to JPEG at quality 70

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OPTIMIZED_DIR="${PROJECT_DIR}/output/optimized"

INPUT="${1:?Usage: $0 <input.html> [output.html]}"
OUTPUT="${2:-${INPUT%.html}-base64.html}"

# Resolve relative paths
[[ "$INPUT" != /* ]] && INPUT="${PROJECT_DIR}/${INPUT}"
[[ "$OUTPUT" != /* ]] && OUTPUT="${PROJECT_DIR}/${OUTPUT}"

mkdir -p "$OPTIMIZED_DIR"

echo "Input:  $INPUT"
echo "Output: $OUTPUT"
echo ""

# Start with a copy
cp "$INPUT" "$OUTPUT"

# Find all image files referenced in the HTML (local paths in output/)
# and all hosted URLs pointing to images we have locally
process_image() {
    local src="$1"
    local filename="$2"
    local max_dimension="$3"
    local local_path=""

    # Check common locations for the source image
    for candidate in \
        "${PROJECT_DIR}/output/${filename}" \
        "${PROJECT_DIR}/output/newsletter_${filename}" \
        "${PROJECT_DIR}/${filename}"; do
        if [[ -f "$candidate" ]]; then
            local_path="$candidate"
            break
        fi
    done

    if [[ -z "$local_path" ]]; then
        echo "  SKIP: Cannot find local file for ${filename}"
        return
    fi

    local basename="${filename%.*}"
    local optimized="${OPTIMIZED_DIR}/${basename}.jpg"

    echo "  Optimizing: ${local_path} -> ${optimized} (max ${max_dimension}px)"
    sips -s format jpeg -s formatOptions 70 -Z "$max_dimension" "$local_path" --out "$optimized" > /dev/null 2>&1

    local size=$(wc -c < "$optimized" | tr -d ' ')
    local b64=$(base64 -i "$optimized")
    local b64_len=${#b64}

    echo "  Size: ${size} bytes -> ${b64_len} chars base64"

    # Escape special characters in src for sed
    local escaped_src=$(printf '%s\n' "$src" | sed 's/[[\.*^$()+?{|]/\\&/g; s/]/\\]/g')

    # Replace in output file
    sed -i '' "s|${escaped_src}|data:image/jpeg;base64,${b64}|g" "$OUTPUT"
    echo "  Embedded."
}

echo "Processing images..."
echo ""

# Extract all img src values and process each
grep -oE 'src="[^"]*"' "$OUTPUT" | sed 's/src="//;s/"$//' | while read -r src; do
    # Skip already-embedded base64 images
    [[ "$src" == data:* ]] && continue

    filename=$(basename "$src")

    # Determine max dimension based on context
    # Banner images are 640px wide, icons are 100px displayed (200px for retina)
    if echo "$src" | grep -qi "banner"; then
        max_dim=640
    else
        max_dim=200
    fi

    echo "Found: $src"
    process_image "$src" "$filename" "$max_dim"
    echo ""
done

final_size=$(wc -c < "$OUTPUT" | tr -d ' ')
echo "Done! Output: $OUTPUT ($(echo "scale=0; $final_size / 1024" | bc)K)"
echo ""
echo "Next steps:"
echo "  1. Open $OUTPUT in Safari"
echo "  2. Cmd+A, Cmd+C"
echo "  3. Paste into Outlook email"
