#!/usr/bin/env bash
set -euo pipefail

# Gather inputs from Docker args
MODE="$1"
INPUT="$2"
OUTPUT="$3"
PATCH_FILE="${4:-}"
PATCH_YAML="${5:-}"
ALWAYS_PATCH="${6:-}"
BRANCH_NAME="${7:-}"
AUTO_PR="${8:-false}"
UPLOAD_FILES="${9:-}"

# Robust argument checks
if [[ -z "$MODE" ]]; then
  echo "::error ::Missing required argument: MODE (should be 'json2vipb' or similar)" >&2
  exit 1
fi
if [[ -z "$INPUT" ]] || [[ -z "$OUTPUT" ]]; then
  echo "::error ::Missing required input or output file argument." >&2
  exit 1
fi
if [[ ! -f "$INPUT" ]]; then
  echo "::error ::Input file '$INPUT' does not exist." >&2
  exit 1
fi

# Prepare patch files if inline YAML provided
if [[ -n "$PATCH_YAML" ]]; then
  echo "$PATCH_YAML" > /tmp/inline_patch.yml
  PATCH_FILE="/tmp/inline_patch.yml"
fi

if [[ -n "$ALWAYS_PATCH" ]]; then
  echo "$ALWAYS_PATCH" > /tmp/always_patch.yml
else
  touch /tmp/always_patch.yml
fi

# Run the CLI tool with all relevant arguments
VipbJsonTool "$MODE" "$INPUT" "$OUTPUT" "$PATCH_FILE" /tmp/always_patch.yml "$BRANCH_NAME" "$AUTO_PR"

# Upload artifacts if requested
if [[ -n "$UPLOAD_FILES" ]]; then
  tar czf /tmp/artifacts.tgz $UPLOAD_FILES || true
  echo "::set-output name=artifact::/tmp/artifacts.tgz"
fi