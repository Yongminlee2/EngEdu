#!/bin/sh
# 안드로이드 앱과 **같은 자산 파일**을 아이폰 번들에 넣는다 (빌드 단계에서 부른다).
#
# 레이아웃 XML·문구(values*/strings.xml)·색·그림·문제 팩(assets/)은 안드로이드
# app/src/main 아래 한 벌만 두고, 빌드할 때 번들의 res/·assets/ 로 복사한다.
# 아이폰 쪽에 사본을 두면 두 벌이 어긋난다.
#
# 예외는 효과음 — 아이폰이 OGG 를 못 틀어서 tools/convert-sfx.sh 로 만든 m4a 사본을
# ios/Sound 에 둔다(원본 지문은 tools/sfx-sources.txt).
set -e

SRC="$SRCROOT/../app/src/main"
DST="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$DST/res" "$DST/assets" "$DST/sound"

# res: 소리(raw)·런처 아이콘 밀도별 사본은 빼고
/usr/bin/rsync -a --delete \
  --exclude 'raw/' --exclude 'mipmap-mdpi/' --exclude 'mipmap-hdpi/' --exclude 'mipmap-xhdpi/' --exclude 'mipmap-xxhdpi/' \
  "$SRC/res/" "$DST/res/"
/usr/bin/rsync -a --delete "$SRC/assets/" "$DST/assets/"
/usr/bin/rsync -a --delete "$SRCROOT/Sound/" "$DST/sound/"

# 홈 화면 앱 이름(언어별)도 안드로이드 strings.xml 한 벌에서 만든다
/usr/bin/python3 "$SRCROOT/tools/gen-infoplist-strings.py" "$SRC/res" "$DST"
