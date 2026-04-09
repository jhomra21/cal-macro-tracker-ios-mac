#!/bin/sh
set -eu

root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$root" ]; then
  echo "error: --root is required" >&2
  exit 1
fi

findings_file=$(mktemp)
trap 'rm -f "$findings_file"' EXIT HUP INT TERM

find "$root" -type f \( -name '.env.example' -o -name '.dev.vars.example' -o -name '*.env.example' \) \
  ! -path '*/.git/*' \
  ! -path '*/DerivedData/*' \
  ! -path '*/.build/*' \
  ! -path '*/build/*' \
  ! -path '*/node_modules/*' | LC_ALL=C sort | while IFS= read -r file_path; do
  awk -v file_path="$file_path" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }

    function is_placeholder(value) {
      return value ~ /^(YOUR_|REPLACE_|CHANGE_ME|EXAMPLE_|<|\*{4,})/
    }

    function normalize_key(value) {
      value = trim(value)
      sub(/^export[[:space:]]+/, "", value)
      return trim(value)
    }

    function normalize_value(value, first_char, last_char) {
      value = trim(value)
      if (length(value) >= 2) {
        first_char = substr(value, 1, 1)
        last_char = substr(value, length(value), 1)
        if ((first_char == "\"" && last_char == "\"") || (first_char == "'"'"'" && last_char == "'"'"'")) {
          value = substr(value, 2, length(value) - 2)
        }
      }
      return value
    }

    /^[[:space:]]*#/ || /^[[:space:]]*$/ {
      next
    }

    {
      separator_index = index($0, "=")
      if (separator_index == 0) {
        next
      }

      key = normalize_key(substr($0, 1, separator_index - 1))
      value = normalize_value(substr($0, separator_index + 1))
      upper_key = toupper(key)
      if (upper_key ~ /(KEY|TOKEN|SECRET|PASSWORD)/ && value != "" && is_placeholder(value) == 0) {
        printf "%s:%d: example file contains non-placeholder secret for %s\n", file_path, NR, key
      }
    }
  ' "$file_path" >> "$findings_file"
done

if [ ! -s "$findings_file" ]; then
  echo "example-env-secrets: no non-placeholder example secrets detected"
  exit 0
fi

echo "example-env-secrets: findings detected" >&2
cat "$findings_file" | while IFS= read -r line; do
  echo "- $line" >&2
done
exit 1
