#!/usr/bin/env bash
set -euo pipefail

# write inline patch yaml if provided
if [[ -n "${INPUT_PATCH_YAML:-}" && -z "${INPUT_PATCH_FILE:-}" ]]; then
  echo "$INPUT_PATCH_YAML" > /tmp/inline_patch.yml
  PATCH_FILE=/tmp/inline_patch.yml
else
  PATCH_FILE="$INPUT_PATCH_FILE"
fi

# write always‑patch yaml (may be empty)
if [[ -n "${INPUT_ALWAYS_PATCH_FIELDS:-}" ]]; then
  echo "$INPUT_ALWAYS_PATCH_FIELDS" > /tmp/always_patch.yml
else
  touch /tmp/always_patch.yml
fi

# run CLI
VipbJsonTool "$INPUT_MODE" "$INPUT_IN" "$INPUT_OUT" "$PATCH_FILE" /tmp/always_patch.yml "$INPUT_BRANCH_NAME" "$INPUT_AUTO_OPEN_PR"

# bundle artifacts if requested
if [[ -n "${INPUT_UPLOAD_FILES:-}" ]]; then
  mkdir -p /tmp/vipb_art
  while IFS= read -r f; do cp "$f" /tmp/vipb_art/ ; done <<< "$INPUT_UPLOAD_FILES"
  tar -C /tmp -czf /github/workspace/vipb_artifacts.tgz vipb_art
  echo "artifacts_path=vipb_artifacts.tgz" >> "$GITHUB_OUTPUT"
fi
