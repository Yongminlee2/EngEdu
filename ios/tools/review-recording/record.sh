#!/bin/bash
# 실기기에서 심사 회신용 화면 녹화를 만든다. 결과: Build/review-recording/<시각>/ 에 영상(.mp4)과 단계별 화면.
#
#   tools/review-recording/record.sh <기기 UDID>  [테스트 이름, 기본 ReviewWalkthroughUITests]
#   그다음 swift rotate-video.swift <결과>/recording.mp4 <결과>/rotated.mp4  (세로 앱이라 보통 필요 없다)
#
# 먼저 삐약영어(com.peep.english)을 그 폰에 깔아 둔다(개발 서명 빌드 → xcrun devicectl device install app).
# 폰은 잠금을 풀고 녹화 동안 만지지 않는다. Xcode 의 UI 테스트 자동 화면 녹화를 지우지 않게 남겨서 꺼낸다
# (명령줄 도구로 맥에서 아이폰 화면을 직접 받으려면 카메라 권한이 필요해 막힌다).
set -euo pipefail
cd "$(dirname "$0")"
DEV="${1:?기기 UDID}"; TEST="${2:-ReviewWalkthroughUITests}"
ROOT="$(cd ../.. && pwd)/build"; DD="$ROOT/Build/review-dd"; OUT="$ROOT/Build/review-recording/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
xcodegen generate >/dev/null
xcodebuild build-for-testing -project EnglishReview.xcodeproj -scheme ReviewUITests -destination id="$DEV" \
  -derivedDataPath "$DD" -allowProvisioningUpdates 2>&1 | grep -E "error:|\*\* " || true
RUN=$(ls "$DD"/Build/Products/*.xctestrun | head -1)
# 녹화·첨부를 성공한 시험에서도 남기고, 화면 녹화로 받는다. xctestrun 은 Build/Products 안에 둬야 경로가 맞는다.
python3 -I - "$RUN" <<'PY'
import plistlib, sys
p = sys.argv[1]; d = plistlib.load(open(p, 'rb'))
targets = [t for c in d.get('TestConfigurations', []) for t in c['TestTargets']] if 'TestConfigurations' in d \
          else [v for k, v in d.items() if isinstance(v, dict) and 'TestBundlePath' in v]
for t in targets:
    t['SystemAttachmentLifetime'] = 'keepAlways'
    t['UserAttachmentLifetime'] = 'keepAlways'
    t['PreferredScreenCaptureFormat'] = 'screenRecording'
plistlib.dump(d, open(p, 'wb'))
print('xctestrun 고침:', len(targets))
PY
xcodebuild test-without-building -xctestrun "$RUN" -destination id="$DEV" \
  -only-testing:"ReviewUITests/$TEST" -resultBundlePath "$OUT/result.xcresult" 2>&1 | grep -E "Test Case|\*\* " || true
xcrun xcresulttool export attachments --path "$OUT/result.xcresult" --output-path "$OUT/attachments" >/dev/null
python3 -I - "$OUT" <<'PY'
import json, os, shutil, sys
out = sys.argv[1]; att = os.path.join(out, 'attachments')
for t in json.load(open(os.path.join(att, 'manifest.json'))):
    for a in t['attachments']:
        name = a['suggestedHumanReadableName']; src = os.path.join(att, a['exportedFileName'])
        if name.lower().startswith('screen recording') or src.endswith(('.mp4', '.mov')):
            shutil.copy(src, os.path.join(out, 'recording' + os.path.splitext(src)[1])); print('영상:', name)
        elif name[:2].isdigit():   # 단계별 화면 "03_scrambled_0_<uuid>.png" → "03_scrambled.png"
            shutil.copy(src, os.path.join(out, name.split('_0_')[0] + os.path.splitext(src)[1]))
print(out)
PY
