#!/usr/bin/env bash
# Synthesizes the phone sounds: message receive and send, notification, ringtone and wrong code. Sine notes with a
# soft attack and an exponential decay, written to assets/story/music/<name>.mp3. No samples, so nothing to
# license from anyone else.
#
#   samples/last_seen/tools/phone-sounds.sh
#
# Peaks match the sounds they replaced, so mixer volumes stay the same. The ringtone repeats every 2.8 s, so its
# loop has no seam. Every sound lasts at least 0.12 s (see ui-sounds.sh).
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
out_dir="$here/assets/story/music"
tmp=$(mktemp -d)
trap 'mv "$tmp" "${TMPDIR:-/tmp}/phone-sounds.$$"' EXIT

# A note at time $1, frequency $2, amplitude $3 and decay rate $4, with a quick-fading octave on top. T is the time.
note() {
  echo "$3*gte(T,$1)*(sin(2*PI*$2*(T-$1))+0.25*sin(4*PI*$2*(T-$1))*exp(-(T-$1)*20))*exp(-(T-$1)*$4)*(1-exp(-(T-$1)*400))"
}

# name, duration (s), expression in T, loop period (s), peak (dB)
make_one() {
  local name=$1 dur=$2 expr="${3//T/(mod(t,$4))}" peak=$5 fade_at measured
  fade_at=$(awk -v d="$dur" 'BEGIN { printf "%.3f", d - 0.02 }')
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "aevalsrc='$expr':s=44100:d=$dur" \
    -af "afade=t=out:st=$fade_at:d=0.02" -ac 1 "$tmp/$name.wav"
  measured=$(ffmpeg -hide_banner -i "$tmp/$name.wav" -af volumedetect -f null - 2>&1 | awk '/max_volume/ { print $5 }')
  ffmpeg -hide_banner -loglevel error -y -i "$tmp/$name.wav" \
    -af "volume=$(awk -v p="$peak" -v m="$measured" 'BEGIN { print p - m }')dB" \
    -ac 1 -ar 44100 -c:a libmp3lame -b:a 64k "$out_dir/$name.mp3"
  echo "saved $out_dir/$name.mp3 ($dur s)"
}

# Two notes up: A5, E6.
make_one sfx_msg_receive 0.25 "$(note 0 880 0.5 28)+$(note 0.07 1318.5 0.5 22)" 10 -23.5
# A quick rising blip.
make_one sfx_msg_send 0.15 "0.6*sin(2*PI*(600*T+3000*T*T))*exp(-T*30)*(1-exp(-T*400))" 10 -26
# A two-note chime: C6, G6.
make_one sfx_notification 0.6 "$(note 0 1046.5 0.5 9)+$(note 0.12 1568 0.45 8)" 10 -24.5
# Two low buzzes at G3, square-ish from odd harmonics, with soft edges so they don't click.
buzz="(sin(2*PI*196*T)+sin(6*PI*196*T)/3+sin(10*PI*196*T)/5)"
edges="(clip(T*200,0,1)*clip((0.14-T)*200,0,1)+clip((T-0.2)*200,0,1)*clip((0.34-T)*200,0,1))"
make_one sfx_wrong_code 0.4 "0.4*$buzz*$edges" 10 -22.2
# A marimba-like phrase, E6 C6 G6 C6, then E6 C6 G6 C7, twice.
ring=""
for n in "0 1318.5" "0.15 1046.5" "0.3 1568" "0.45 1046.5" "0.75 1318.5" "0.9 1046.5" "1.05 1568" "1.2 2093"; do
  read -r at freq <<< "$n"
  ring+="${ring:++}$(note "$at" "$freq" 0.35 9)"
done
make_one sfx_phone_ring 5.6 "$ring" 2.8 -23.6
