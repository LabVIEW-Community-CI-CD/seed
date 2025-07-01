#!/usr/bin/env bash
set -euo pipefail

# Gather inputs
MODE="$1"
ARGS="$2"
PATCH_FILE="${3:-}"
PATCH_YAML="${4:-}"
ALWAYS_PATCH="${5:-}"
BRANCH_NAME="${6:-}"
AUTO_PR="${7:-false}"
UPLOAD_FILES="${8:-}"

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

# Run the CLI
VipbJsonTool "$MODE" $ARGS "$PATCH_FILE" /tmp/always_patch.yml "$BRANCH_NAME" "$AUTO_PR"

# Upload artifacts if requested
if [[ -n "$UPLOAD_FILES" ]]; then
  tar czf /tmp/artifacts.tgz $UPLOAD_FILES || true
  echo "::set-output name=artifact::/tmp/artifacts.tgz"
fi