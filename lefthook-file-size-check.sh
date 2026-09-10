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
  # A `paths:` entry is keyed on the repo-relative path, and callers name
  # files both ways ("SPEC.md" from lefthook, "./SPEC.md" from a find), so the
  # leading "./" is normalized away before the lookup. Without this an
  # exemption silently stops applying depending on who invoked the check.
  rel="${f#./}"
  limit=$(get-file-size-limit "$ext" "$config" "$rel")
  if [ -z "$limit" ]; then
    continue
  fi
  size=$(wc -c <"$f" | tr -d ' ')
  if [ "$size" -gt "$limit" ]; then
    # Name the RULE that decided, so a violation says which line of the
    # config to look at -- a path exemption and an extension limit are
    # edited in different places.
    rule=".$ext"
    if [ "$limit" != "$(get-file-size-limit "$ext" "$config")" ]; then
      rule="path: $rel"
    fi
    violations+=("$f: ${size} bytes > ${limit} limit (${rule})")
  fi
done

if [ ${#violations[@]} -gt 0 ]; then
  echo "File size limit exceeded:"
  for v in "${violations[@]}"; do
    echo "  - $v"
  done
  exit 1
fi
