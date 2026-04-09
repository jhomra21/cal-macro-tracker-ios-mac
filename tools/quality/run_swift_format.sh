#!/bin/sh
set -eu

config_path=".swift-format"
mode="lint"
target_path="cal-macro-tracker"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config)
      config_path="$2"
      shift 2
      ;;
    --mode)
      mode="$2"
      shift 2
      ;;
    --target)
      target_path="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$config_path" ]; then
  echo "error: missing swift-format config: $config_path" >&2
  exit 1
fi

if ! command -v swift-format >/dev/null 2>&1; then
  echo "warning: swift-format is not installed; skipping format check."
  echo "install with: brew install swift-format"
  exit 0
fi

case "$mode" in
  lint)
    swift-format lint --strict --parallel --recursive --configuration "$config_path" "$target_path"
    ;;
  format)
    swift-format format --in-place --parallel --recursive --configuration "$config_path" "$target_path"
    ;;
  *)
    echo "error: unsupported mode: $mode" >&2
    exit 1
    ;;
esac
