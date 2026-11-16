#!/usr/bin/env bash
# One image for Last Seen with the Codex CLI image tool (ChatGPT login), spec §6.2. Adapted from menolakngantor's
# codex-image.sh. Keeps input tokens low:
#   - runs in an empty temp dir (no repo AGENTS.md / CLAUDE.md pulled into context)
#   - --ignore-user-config (no MCP servers, profiles or extra instructions)
#   - the prompt goes in inline, and Codex is told not to touch files or run commands
#   - this script copies the image out of ~/.codex/generated_images, not Codex
#
# Usage: samples/last_seen/tools/codex-image.sh <asset> [style-ref.png]
#   <asset> is the asset path under assets/story, e.g. bg/bg_seawall_night.png. Its prompt is
#   art/prompts/<asset name>.txt, kept in git so any image can be regenerated. The image replaces the placeholder.
# Prints the Codex token usage line. Exit 1 if no image was produced.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
asset=$1
ref=${2:-}
name=$(basename "${asset%.*}")
prompt_file="$here/art/prompts/$name.txt"
out="$here/assets/story/$asset"

[[ -f "$prompt_file" ]] || { echo "no prompt: $prompt_file" >&2; exit 1; }
[[ -z "$ref" || -f "$ref" ]] || { echo "no style reference: $ref" >&2; exit 1; }

work=$(mktemp -d -t codex-img)
log="$work/run.jsonl"
args=(exec --skip-git-repo-check --ephemeral --ignore-user-config --json -s read-only -C "$work")
[[ -n "$ref" ]] && args+=(-i "$ref")

instructions="Call your image generation tool exactly once with the prompt below$([[ -n "$ref" ]] && echo ', using the attached image as a style and character reference'). Do not read files, load skills or run shell commands. After the tool returns, reply with just: done.

PROMPT:
$(cat "$prompt_file")"

# The prompt goes in on stdin: `-i` takes several values and would swallow a positional prompt.
printf '%s\n' "$instructions" > "$work/prompt.txt"
codex "${args[@]}" - < "$work/prompt.txt" > "$log" 2>&1 || true

thread=$(jq -rR 'fromjson? | select(.type? == "thread.started") | .thread_id' "$log" 2>/dev/null | head -1 || true)
jq -cR 'fromjson? | select(.type? == "turn.completed") | {usage}' "$log" 2>/dev/null || true
img=$( [[ -n "$thread" ]] && ls -t "$HOME/.codex/generated_images/$thread/"*.png 2>/dev/null | head -1 || true)

if [[ -z "$img" ]]; then
  echo "no image produced; log: $log" >&2
  exit 1
fi
# The untouched image goes to art/.raw/ (git-ignored), so it can be keyed or graded again without a new run.
raw="$here/art/.raw/$name.png"
mkdir -p "$(dirname "$out")" "$(dirname "$raw")"
cp "$img" "$raw"
"$(dirname "$0")/finish-image.sh" "$raw" "$asset"
