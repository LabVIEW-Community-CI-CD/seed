#!/usr/bin/env bash
set -eo pipefail

MODE="$1"
ARGS="$2"
PATCH_FILE="${3:-}"
PATCH_YAML="${4:-}"
ALWAYS_PATCH="${5:-}"
BRANCH_NAME="${6:-}"
AUTO_PR="${7:-false}"
UPLOAD_FILES="${8:-}"

# prepare patches
if [[ -n "$PATCH_YAML" ]]; then
  echo "$PATCH_YAML" > /tmp/inline_patch.yml
  PATCH_FILE="/tmp/inline_patch.yml"
fi

if [[ -n "$ALWAYS_PATCH" ]]; then
  echo "$ALWAYS_PATCH" > /tmp/always_patch.yml
else
  touch /tmp/always_patch.yml
fi

# run tool
VipbJsonTool "$MODE" $ARGS "$PATCH_FILE" /tmp/always_patch.yml "$BRANCH_NAME" "$AUTO_PR"

# upload artifacts
if [[ -n "$UPLOAD_FILES" ]]; then
  echo "$UPLOAD_FILES" | tr '\n' '\0' | while IFS= read -r -d '' f; do
    if [[ -f "$f" ]]; then
      tar -rvf /tmp/artifacts.tar "$f"
    fi
  done
  gzip /tmp/artifacts.tar
  echo "::set-output name=artifact::/tmp/artifacts.tar.gz"
fi
