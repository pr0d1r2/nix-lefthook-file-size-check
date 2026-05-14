# shellcheck shell=bash
# Lefthook-compatible file size limit checker.
# Reads per-extension limits from a YAML config file.
# Config path: LEFTHOOK_FILE_SIZE_CONFIG (default: config/lefthook/file_size_limits.yml)
# Usage: lefthook-file-size-check file1 [file2 ...]
# NOTE: sourced by writeShellApplication - no shebang or set needed.

if [ $# -eq 0 ]; then
    exit 0
fi

config="${LEFTHOOK_FILE_SIZE_CONFIG:-config/lefthook/file_size_limits.yml}"

if [ ! -f "$config" ]; then
    echo "file-size-check: config not found: $config" >&2
    exit 1
fi

violations=()

for f in "$@"; do
    [ -f "$f" ] || continue
    basename="${f##*/}"
    ext="${basename##*.}"
    if [ "$ext" = "$basename" ]; then
        ext="$basename"
    fi
    limit=$(get-file-size-limit "$ext" "$config")
    if [ -z "$limit" ]; then
        continue
    fi
    size=$(wc -c <"$f" | tr -d ' ')
    if [ "$size" -gt "$limit" ]; then
        violations+=("$f: ${size} bytes > ${limit} limit (.$ext)")
    fi
done

if [ ${#violations[@]} -gt 0 ]; then
    echo "File size limit exceeded:"
    for v in "${violations[@]}"; do
        echo "  - $v"
    done
    exit 1
fi
