#!/usr/bin/env bash
# Synthesizes the menu blips that RetroSounds plays (lib/ui/retro.dart): decaying square-wave notes, written to
# assets/story/music/sfx_ui_<name>.mp3. No samples, so nothing to credit.
#
#   samples/last_seen/tools/ui-sounds.sh            all of them
#   samples/last_seen/tools/ui-sounds.sh cursor     just one (cursor, confirm, cancel or start)
#
# Every blip ends in a short silent tail and lasts at least 0.12 s: Android's MediaPlayer fails with
# MEDIA_ERROR_SYSTEM on an MP3 of only a few frames (the first cursor blip was 0.05 s).
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
out_dir="$here/assets/story/music"
tail_s=0.08

# name: amplitude, decay time constant (s), then "Hz:seconds" per note, in order.
recipe() {
  case "$1" in
    cursor) echo "0.21 0.025 1568:0.05" ;;                    # G6
    confirm) echo "0.22 0.08 1047:0.06 1568:0.12" ;;          # C6, G6
    cancel) echo "0.24 0.06 784:0.05 523:0.09" ;;             # G5, C5
    start) echo "0.24 0.18 523:0.08 784:0.08 1047:0.34" ;;    # C5, G5, C6
    *) return 1 ;;
  esac
}

make_one() {
  local name=$1 spec amp tau notes=() expr="" start=0 freq dur end
  spec=$(recipe "$name") || { echo "unknown sound: $name" >&2; return 1; }
  read -r amp tau _ <<< "$spec"
  read -ra notes <<< "${spec#* * }"
  for note in "${notes[@]}"; do
    freq=${note%%:*}
    dur=${note##*:}
    end=$(awk -v a="$start" -v b="$dur" 'BEGIN { print a + b }')
    expr+="${expr:++}gte(t,$start)*lt(t,$end)*sgn(sin(2*PI*$freq*(t-$start)))"
    start=$end
  done
  local out="$out_dir/sfx_ui_$name.mp3"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "aevalsrc='$amp*exp(-t/$tau)*($expr)':s=44100:d=$start" \
    -af "apad=pad_dur=$tail_s" -ac 1 -c:a libmp3lame -b:a 64k "$out"
  echo "saved $out ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out") s)"
}

names=("$@")
[[ ${#names[@]} -gt 0 ]] || names=(cursor confirm cancel start)
for name in "${names[@]}"; do make_one "$name"; done
