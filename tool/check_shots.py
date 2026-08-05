# -*- coding: utf-8 -*-
"""찍힌 스크린샷을 검사한다.

  · 장수가 모자란 언어
  · 07_answer 가 정답(초록) 패널이 아닌 언어
  · 서로 똑같은 그림(내비게이션이 실패해 같은 화면을 두 번 찍은 경우)

  python tool/check_shots.py
"""
import hashlib, io, os, sys
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
app = os.path.basename(ROOT)
expect = int(sys.argv[1]) if len(sys.argv) > 1 else 7
SRC = os.path.join(ROOT, "store", "screenshots")

if not os.path.isdir(SRC):
    print("아직 찍힌 게 없다:", SRC); sys.exit()

bad_answer, short, dup = [], [], []
for lang in sorted(os.listdir(SRC)):
    d = os.path.join(SRC, lang)
    if not os.path.isdir(d):
        continue
    files = sorted(f for f in os.listdir(d) if f.endswith(".png"))
    if len(files) < expect:
        short.append((lang, len(files)))

    # 07_answer 가 초록 패널인가
    p = os.path.join(d, "07_answer.png")
    if os.path.exists(p):
        im = Image.open(p).convert("RGB")
        w, h = im.size
        green = False
        for frac in (0.900, 0.912, 0.888, 0.925, 0.875):
            r, g, b = im.getpixel((w // 2, int(h * frac)))
            if g > r + 40 and g > b + 40:
                green = True
                break
        if not green:
            bad_answer.append(lang)

    # 같은 그림이 두 번
    seen = {}
    for f in files:
        h_ = hashlib.md5(open(os.path.join(d, f), "rb").read()).hexdigest()
        if h_ in seen:
            dup.append(f"{lang}: {seen[h_]} = {f}")
        seen[h_] = f

print(f"== {app} ==")
print(f"  언어 폴더 {len([x for x in os.listdir(SRC) if os.path.isdir(os.path.join(SRC, x))])}개")
print(f"  장수 부족: {short if short else '없음'}")
print(f"  정답 화면 아님: {bad_answer if bad_answer else '없음'}")
print(f"  같은 그림 중복: {dup if dup else '없음'}")
if bad_answer:
    print("\n  다시 찍기:")
    print(f"    python tool/shoot_all_langs.py {' '.join(bad_answer)}")
