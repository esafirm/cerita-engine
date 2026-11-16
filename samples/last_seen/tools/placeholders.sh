#!/usr/bin/env bash
# Fills every asset the story references but doesn't have yet with a placeholder (spec §6), so writing and code
# can move before the art and audio land. Real files keep the same names and simply replace these.
#
#   samples/last_seen/tools/placeholders.sh
#
# Reads the missing list from `cerita_tools assets --json`. Voice clips are left out: tools/voice.mjs renders them.
# Every file made here is listed in art/placeholders.txt, so `--list` shows what still needs real art.
#   placeholders.sh --list    print the placeholders that haven't been replaced yet
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
story="$here/story"
assets="$here/assets/story"
ledger="$here/art/placeholders.txt"
repo=$(cd "$here/../.." && pwd)

if [[ "${1:-}" == "--list" ]]; then
  # A placeholder is replaced once its file differs from what this script made, so the ledger keeps a hash.
  [[ -f "$ledger" ]] || exit 0
  while read -r path hash; do
    [[ -f "$assets/$path" && "$(shasum "$assets/$path" | cut -d' ' -f1)" == "$hash" ]] && echo "$path"
  done < "$ledger"
  exit 0
fi

# A stable color per name: hue from the name's hash.
color() { # name lightness(0-100) -> 0xRRGGBB
  local h=$(( 0x$(printf '%s' "$1" | shasum | cut -c1-6) % 360 )) l=$2
  awk -v h="$h" -v l="$l" 'BEGIN {
    s = 0.45; l = l / 100; c = (1 - (2 * l - 1 < 0 ? 1 - 2 * l : 2 * l - 1)) * s
    x = c * (1 - ((h / 60) % 2 - 1 < 0 ? 1 - (h / 60) % 2 : (h / 60) % 2 - 1)); m = l - c / 2
    if (h < 60) { r = c; g = x; b = 0 } else if (h < 120) { r = x; g = c; b = 0 } else if (h < 180) { r = 0; g = c; b = x }
    else if (h < 240) { r = 0; g = x; b = c } else if (h < 300) { r = x; g = 0; b = c } else { r = c; g = 0; b = x }
    printf "0x%02X%02X%02X", (r + m) * 255, (g + m) * 255, (b + m) * 255 }'
}

ff() { ffmpeg -hide_banner -loglevel error -y "$@"; }

# The character a sprite or avatar belongs to: the file name up to its first _.
owner() { local base; base=$(basename "$1"); echo "${base%%_*}"; }

make_one() { # kind path
  local kind=$1 path=$2 out="$assets/$2" name
  # ffmpeg here has no WebP encoder: draw a PNG, then cwebp it.
  local final=$out
  [[ "$final" == *.webp ]] && out="${TMPDIR:-/tmp}/placeholder.$$.png"
  name=$(basename "${path%.*}")
  mkdir -p "$(dirname "$out")"
  case "$kind" in
    background | cg)
      # Portrait, like the phone layout. Night scenes are darker.
      local l=38; [[ "$name" == *night* ]] && l=18
      ff -f lavfi -i "gradients=s=1080x1920:c0=$(color "$name" $((l + 14))):c1=$(color "$name" "$l"):x0=0:y0=0:x1=0:y1=1920:n=2" \
        -frames:v 1 "$out" ;;
    sprite)
      # A flat silhouette (head and shoulders) on transparency, one color per character.
      local c; c=$(color "$(owner "$path")" 55)
      ff -f lavfi -i "color=c=$c:s=600x1300,format=rgba" -vf \
        "geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='255*(lt(hypot(X-300,Y-260),150)+gt(Y,440)*lt(abs(X-300),120+(Y-440)*0.35)*gt(1300-Y,0))'" \
        -frames:v 1 "$out" ;;
    avatar)
      local c; c=$(color "$(owner "$path")" 55)
      ff -f lavfi -i "color=c=$c:s=256x256,format=rgba" -vf "geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='255*lt(hypot(X-128,Y-128),128)'" \
        -frames:v 1 "$out" ;;
    image | clue)
      ff -f lavfi -i "gradients=s=1080x1350:c0=$(color "$name" 70):c1=$(color "$name" 40):x0=0:y0=0:x1=1080:y1=1350:n=2" \
        -frames:v 1 "$out" ;;
    video)
      ff -f lavfi -i "gradients=s=720x1280:c0=$(color "$name" 60):c1=$(color "$name" 25):speed=0.02:n=2" -t 3 -pix_fmt yuv420p "$out" ;;
    music | ambience)
      ff -f lavfi -i anullsrc=r=44100:cl=stereo -t 4 -c:a libmp3lame -q:a 9 "$out" ;;
    sfx)
      ff -f lavfi -i "sine=frequency=880:duration=0.12" -af "volume=0.3" -c:a libmp3lame -q:a 9 "$out" ;;
    *)
      return 1 ;;
  esac
  if [[ "$final" != "$out" ]]; then
    [[ -s "$out" ]] && cwebp -quiet -q 80 "$out" -o "$final"; out=$final
  fi
  [[ -s "$out" ]] || { echo "failed: $path" >&2; return 1; }
  echo "$path $(shasum "$out" | cut -d' ' -f1)" >> "$ledger"
  echo "placeholder $path"
}

mkdir -p "$(dirname "$ledger")"
missing=$(cd "$repo" && dart run cerita_tools assets "$story" --json)
made=0
while IFS=$'\t' read -r kind path; do
  [[ "$kind" == voice || "$kind" == voice_note ]] && continue
  make_one "$kind" "$path" && made=$((made + 1))
done < <(jq -r 'to_entries[] | .key as $k | .value[] | [$k, .] | @tsv' <<< "$missing")
echo "$made placeholders made. Voice clips: run tools/voice.mjs."
