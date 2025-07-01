#!/usr/bin/env bash
set -euo pipefail

# Gather inputs from Docker args
MODE="$1"
ARGS="$2"
PATCH_FILE="${3:-}"
PATCH_YAML="${4:-}"
ALWAYS_PATCH="${5:-}"
BRANCH_NAME="${6:-}"
AUTO_PR="${7:-false}"
UPLOAD_FILES="${8:-}"

# Parse ARGS into input/output files (assumes "input output")
INPUT_FILE="$(echo $ARGS | awk '{print $1}')"
OUTPUT_FILE="$(echo $ARGS | awk '{print $2}')"

# Robust argument checks
if [[ -z "$MODE" ]]; then
  echo "::error ::Missing required argument: MODE (should be 'json2vipb' or similar)" >&2
  exit 1
fi

if [[ -z "$INPUT_FILE" ]] || [[ -z "$OUTPUT_FILE" ]]; then
  echo "::error ::Missing required input or output file argument in: '$ARGS'" >&2
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "::error ::Input file '$INPUT_FILE' does not exist." >&2
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
VipbJsonTool "$MODE" $ARGS "$PATCH_FILE" /tmp/always_patch.yml "$BRANCH_NAME" "$AUTO_PR"

# Upload artifacts if requested
if [[ -n "$UPLOAD_FILES" ]]; then
  tar czf /tmp/artifacts.tgz $UPLOAD_FILES || true
  echo "::set-output name=artifact::/tmp/artifacts.tgz"
fi