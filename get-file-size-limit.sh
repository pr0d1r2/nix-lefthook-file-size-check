# shellcheck shell=bash
# Looks up the file size limit for a file from a YAML config.
# Usage: get-file-size-limit <extension> <config-file> [<repo-relative-path>]
# Prints the limit in bytes. Prints nothing if no limit found.
#
# Precedence: an exact `paths:` entry beats the `extensions:` entry, which beats
# `default:`. A path entry exists so that ONE known-large file can be declared
# without loosening the limit for every file that shares its extension -- a
# whole-repository spec, a generated inventory, a vendored data file. The
# exemption is then visible in the config, next to a comment saying why, rather
# than hidden in a raised ceiling nobody can attribute.
#
# Sections are respected: a key only counts under the heading it appears below,
# so a path that happens to look like an extension cannot answer for one.
# NOTE: sourced by writeShellApplication - no shebang or set needed.

ext="$1"
config="$2"
path="${3:-}"

awk -v ext="$ext" -v path="$path" '
  /^[[:space:]]*(#|$)/ { next }
  /^default:/ {
    line = $0
    sub(/^default:[[:space:]]*/, "", line)
    sub(/[[:space:]]*#.*$/, "", line)
    gsub(/[[:space:]]/, "", line)
    fallback = line
    next
  }
  /^[^[:space:]]/ {
    section = $0
    sub(/:.*$/, "", section)
    next
  }
  /^  [^[:space:]]/ {
    line = $0
    sub(/^  /, "", line)
    i = index(line, ":")
    if (i == 0) next
    key = substr(line, 1, i - 1)
    val = substr(line, i + 1)
    sub(/[[:space:]]*#.*$/, "", val)
    gsub(/[[:space:]]/, "", val)
    gsub(/^"|"$|^'"'"'|'"'"'$/, "", key)
    if (section == "paths" && path != "" && key == path) byPath = val
    else if (section == "extensions" && key == ext) byExt = val
    next
  }
  END {
    if (byPath != "") print byPath
    else if (byExt != "") print byExt
    else if (fallback != "") print fallback
  }
' "$config" 2>/dev/null || true
