#!/usr/bin/env bash
# The app icons, drawn with codex-image.sh from art/prompts/icon*.txt.
#
# The main icon, Sekar on the Pluit seawall at night (art/prompts/icon.txt): writes art/icon/icon.png at 1024px from
# a source image, then every launcher icon of the app at its own size:
#   - Android legacy ic_launcher, iOS AppIcon (no alpha) and the web icons and favicon: the whole picture
#   - Android adaptive icon (8.0+): the picture fills the 72dp a launcher can show of the 108dp foreground, over the
#     sky colour, so any mask shape (circle, squircle) crops only the corners and never moves the subject
#   - web maskable icons: the picture inside the 80% safe zone, over the sky colour
#   - art/icon/play-store.png at 512px for the Play listing
#
# An alternate icon, one players can pick in Extras (art/prompts/icon_<name>.txt): writes art/icon/icon_<name>.png and
# the Android ic_launcher_<name> icons, legacy and adaptive, for the activity-alias of the same name in the manifest,
# and the iOS alternate icon AppIcon<Name> (ios/Runner/Assets.xcassets/AppIcon<Name>.appiconset).
#
# Both also write the preview the app shows in Extras → App icon, assets/icons/<name>.png (the main one is seawall).
#
# Usage: samples/last_seen/tools/make-icon.sh [source.png]          (default: the current art/icon/icon.png)
#        samples/last_seen/tools/make-icon.sh --alt <name> [source.png]   (default: art/icon/icon_<name>.png)
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
sky=0x05112F
res="$here/android/app/src/main/res"

alt=""
if [[ ${1:-} == --alt ]]; then
  alt=${2:?usage: make-icon.sh --alt <name> [source.png]}
  shift 2
fi
icon="$here/art/icon/icon${alt:+_$alt}.png"
src=${1:-$icon}

[[ -f "$src" ]] || { echo "no source image: $src" >&2; exit 1; }
work=$(mktemp -d -t make-icon)
ffmpeg -hide_banner -loglevel error -y -i "$src" -vf "crop='min(iw,ih)':'min(iw,ih)',scale=1024:1024:flags=lanczos,format=rgb24" \
  "$work/icon.png"
mkdir -p "$(dirname "$icon")"
cp "$work/icon.png" "$icon"
echo "saved ${icon#"$here/"}"

scaled() { ffmpeg -hide_banner -loglevel error -y -i "$icon" -vf "scale=$1:$1:flags=lanczos,format=rgb24" -frames:v 1 "$2"; }
# The picture at $1 px, centred on a $2 px canvas filled with $3 (a colour, or "transparent").
inset() {
  local fill=$3 fmt=rgb24
  [[ $fill == transparent ]] && { fill=0x00000000; fmt=rgba; }
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=$fill:s=$2x$2,format=$fmt" -i "$icon" \
    -filter_complex "[1]scale=$1:$1:flags=lanczos[a];[0][a]overlay=($2-$1)/2:($2-$1)/2:format=auto,format=$fmt" \
    -frames:v 1 "$4"
}

# The Android icon called $1 (ic_launcher, ic_launcher_<name>): the legacy one when $2 is "legacy", and the adaptive
# one, a 108dp foreground per density with the picture on its middle 72dp.
android_icon() {
  local name=$1 density dpi scale canvas
  for density in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
    dpi=${density%%:*}
    scale=${density##*:}
    if [[ $2 == legacy ]]; then
      scaled "$(awk "BEGIN { print int(48 * $scale) }")" "$res/mipmap-$dpi/$name.png"
      echo "  mipmap-$dpi/$name.png"
    fi
    canvas=$(awk "BEGIN { print int(108 * $scale) }")
    inset $((canvas * 2 / 3)) "$canvas" transparent "$res/mipmap-$dpi/${name}_foreground.png"
    echo "  mipmap-$dpi/${name}_foreground.png ($canvas)"
  done
  mkdir -p "$res/mipmap-anydpi-v26"
  cat > "$res/mipmap-anydpi-v26/$name.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tools/make-icon.sh. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/${name}_foreground" />
</adaptive-icon>
EOF
  echo "  mipmap-anydpi-v26/$name.xml"
}

# The iOS alternate icon AppIcon<Name> ($1 the icon's name): one 1024px picture, Xcode draws the other sizes. The
# project lists it in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES, and AppDelegate switches to it.
ios_icon() {
  local set
  set="$here/ios/Runner/Assets.xcassets/AppIcon$(tr '[:lower:]' '[:upper:]' <<< "${1:0:1}")${1:1}.appiconset"
  mkdir -p "$set"
  scaled 1024 "$set/Icon-App-1024x1024@1x.png"
  cat > "$set/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
  echo "  ${set#"$here/"} (1024)"
}

mkdir -p "$here/assets/icons"
scaled 192 "$here/assets/icons/${alt:-seawall}.png"
echo "  assets/icons/${alt:-seawall}.png (192)"

if [[ -n $alt ]]; then
  android_icon "ic_launcher_$alt" legacy
  ios_icon "$alt"
  exit
fi

scaled 512 "$here/art/icon/play-store.png"
echo "  art/icon/play-store.png (512)"

# Every existing full-picture icon, kept at its size. Maskable web icons get the safe zone instead.
while IFS= read -r file; do
  size=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file")
  if [[ $file == *maskable* ]]; then
    inset $((size * 8 / 10)) "$size" "$sky" "$file"
  else
    scaled "$size" "$file"
  fi
  echo "  ${file#"$here/"} ($size)"
done < <(find "$res" "$here/ios/Runner/Assets.xcassets/AppIcon.appiconset" "$here/web" \
  \( -name 'ic_launcher.png' -o -name 'Icon-App-*.png' -o -name 'Icon-*.png' -o -name 'favicon.png' \) 2>/dev/null)

android_icon ic_launcher adaptive
