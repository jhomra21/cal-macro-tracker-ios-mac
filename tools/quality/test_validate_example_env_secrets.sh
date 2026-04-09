#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
validator="$script_dir/validate_example_env_secrets.sh"

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

run_case() {
  case_name="$1"
  expected_status="$2"
  expected_output="$3"
  fixture_content="$4"

  case_root="$tmp_root/$case_name"
  mkdir -p "$case_root"
  printf '%s\n' "$fixture_content" > "$case_root/.dev.vars.example"

  output_file="$tmp_root/$case_name.output"
  if sh "$validator" --root "$case_root" >"$output_file" 2>&1; then
    status=0
  else
    status=$?
  fi

  if [ "$status" -ne "$expected_status" ]; then
    echo "validate-example-env-secrets-test: unexpected exit status for $case_name" >&2
    cat "$output_file" >&2
    exit 1
  fi

  if [ -n "$expected_output" ] && ! grep -F "$expected_output" "$output_file" >/dev/null; then
    echo "validate-example-env-secrets-test: missing expected output for $case_name" >&2
    cat "$output_file" >&2
    exit 1
  fi
}

run_case "unquoted-placeholder" 0 "no non-placeholder example secrets detected" "USDA_API_KEY=YOUR_USDA_API_KEY"
run_case "quoted-placeholder" 0 "no non-placeholder example secrets detected" "USDA_API_KEY=\"YOUR_USDA_API_KEY\""
run_case "quoted-real-secret" 1 "example file contains non-placeholder secret for USDA_API_KEY" "USDA_API_KEY=\"super-secret-value\""
run_case "comments-and-blanks" 0 "no non-placeholder example secrets detected" "# comment

export USDA_API_KEY='YOUR_USDA_API_KEY'
"

echo "validate-example-env-secrets-test: all cases passed"
