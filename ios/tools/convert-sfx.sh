#!/bin/sh
# 안드로이드 res/raw 의 OGG 효과음 → 아이폰용 m4a 사본 (ios/Sound).
# 아이폰은 OGG 를 못 튼다. 안드로이드 소리가 바뀌면 다시 돌린다 (oggdec 필요: brew install vorbis-tools).
# 원본 지문을 tools/sfx-sources.txt 에 적어 두고, 시험(SoundParityTests)이 원본과 대조한다.
set -e
cd "$(dirname "$0")/.."
RAW=../app/src/main/res/raw
mkdir -p Sound
: > tools/sfx-sources.txt
TMP=$(mktemp -d)
for f in "$RAW"/*.ogg; do
  n=$(basename "$f" .ogg)
  oggdec -Q -o "$TMP/$n.wav" "$f"
  afconvert -f m4af -d aac -b 128000 "$TMP/$n.wav" "Sound/$n.m4a"
  echo "$n $(shasum -a 256 "$f" | cut -d' ' -f1)" >> tools/sfx-sources.txt
done
rm -rf "$TMP"
cat tools/sfx-sources.txt
