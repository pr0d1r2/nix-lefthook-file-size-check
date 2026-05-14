# shellcheck shell=bash
# Looks up the file size limit for a given extension from a YAML config.
# Usage: get-file-size-limit <extension> <config-file>
# Prints the limit in bytes. Prints nothing if no limit found.
# NOTE: sourced by writeShellApplication - no shebang or set needed.

ext="$1"
config="$2"

limit=$(grep -F -m1 "  ${ext}:" "$config" 2>/dev/null | awk '{print $2}' || true)
if [ -z "$limit" ]; then
    limit=$(grep "^default:" "$config" | awk '{print $2}' || true)
fi
echo "$limit"
