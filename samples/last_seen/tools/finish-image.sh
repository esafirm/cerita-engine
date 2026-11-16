#!/usr/bin/env bash
# Turns a generated image into the game asset (art/style-guide.md), by kind:
#   sprites/*        key out the flat #00FF00 background and pull the green spill off the edges
#   bg/bg_*          the shared grade: a little less saturation and contrast, a soft blur behind the sprites, grain
#   everything else  as it comes (avatars, CGs, chat photos)
# then writes assets/story/<asset>, as WebP when the name ends in .webp.
#
# Usage: samples/last_seen/tools/finish-image.sh <image.png> <asset>, e.g. art/.raw/bg_warung_day.png bg/bg_warung_day.webp
# codex-image.sh calls it on every new image. Run it alone to re-grade or re-key from art/.raw/.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
src=$1
asset=$2
name=$(basename "${asset%.*}")
out="$here/assets/story/$asset"
work=$(mktemp -d -t finish-img)

key="colorkey=0x00FF00:0.30:0.08,despill=type=green:mix=0.6:expand=0,format=rgba"
grade="eq=saturation=0.85:contrast=0.95:gamma=1.02,gblur=sigma=1.1,noise=alls=6:allf=u"

case "$asset" in
  sprites/*_avatar.*) cp "$src" "$work/done.png" ;;
  sprites/*) ffmpeg -hide_banner -loglevel error -y -i "$src" -vf "$key" "$work/done.png" ;;
  bg/bg_*) ffmpeg -hide_banner -loglevel error -y -i "$src" -vf "$grade" "$work/done.png" ;;
  *) cp "$src" "$work/done.png" ;;
esac

mkdir -p "$(dirname "$out")"
if [[ "$out" == *.webp ]]; then
  cwebp -quiet -q 82 -alpha_q 90 -m 6 "$work/done.png" -o "$out"
else
  cp "$work/done.png" "$out"
fi
echo "saved $out ($(( $(stat -f%z "$out") / 1024 ))K)"
