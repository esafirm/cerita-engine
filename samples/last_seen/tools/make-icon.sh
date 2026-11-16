#!/usr/bin/env bash
# The app icon: "LS" as 5x7 pixel art in a framed navy window, with the logo's two hard shadows (pink, then night).
# Drawn with ffmpeg drawbox only, so it needs no font tools. Writes art/icon/icon.png at 1024px, then every launcher
# icon of the app (Android, iOS, web) at its own size.
#
# Usage: samples/last_seen/tools/make-icon.sh
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
src="$here/art/icon/icon.png"

L=(10000 10000 10000 10000 10000 10000 11111)
S=(01111 10000 10000 01110 00001 00001 11110)
cell=64
x0=160
y0=288

# One drawbox per lit cell of both letters, moved by $1 pixels, in colour $2.
letters() {
  local shift=$1 color=$2 out=""
  for row in 0 1 2 3 4 5 6; do
    for col in 0 1 2 3 4; do
      local y=$((y0 + row * cell + shift))
      [[ ${L[$row]:$col:1} == 1 ]] && out+=",drawbox=x=$((x0 + col * cell + shift)):y=$y:w=$cell:h=$cell:c=$color:t=fill"
      [[ ${S[$row]:$col:1} == 1 ]] && out+=",drawbox=x=$((x0 + (6 + col) * cell + shift)):y=$y:w=$cell:h=$cell:c=$color:t=fill"
    done
  done
  printf '%s' "$out"
}

frame="drawbox=x=72:y=72:w=880:h=880:c=0xF4F1E8:t=24,drawbox=x=112:y=112:w=800:h=800:c=0x6F7BC0:t=8"
mkdir -p "$(dirname "$src")"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=0x111737:s=1024x1024" \
  -vf "$frame$(letters 32 0x0A0E1E)$(letters 16 0xFF8FB8)$(letters 0 0xF4F1E8)" -frames:v 1 "$src"
echo "saved $src"

# Every existing launcher icon, kept at its size.
while IFS= read -r icon; do
  size=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$icon")
  ffmpeg -hide_banner -loglevel error -y -i "$src" -vf "scale=${size/x/:}:flags=area" -frames:v 1 "$icon"
  echo "  $icon ($size)"
done < <(find "$here/android/app/src/main/res" "$here/ios/Runner/Assets.xcassets/AppIcon.appiconset" "$here/web" \
  \( -name 'ic_launcher.png' -o -name 'Icon-App-*.png' -o -name 'Icon-*.png' -o -name 'favicon.png' \) 2>/dev/null)
