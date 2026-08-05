# -*- coding: utf-8 -*-
"""찍은 화면을 스토어에 올릴 수 있게 다듬는다.

    python tool/prep_screenshots.py

폰 상태바(통신사·시계·배터리)와 아래 내비게이션 바를 잘라낸다.
스토어 스크린샷에 남의 폰 시계가 찍혀 있으면 지저분하고, 배터리 잔량 같은 건
심사에서 지적받기도 한다.

색은 256색 팔레트로 줄인다. 파스텔 평면 그림이라 눈으로는 차이가 없는데 용량이 크게 준다.

**원본(`store/screenshots/`)은 다듬은 뒤 지운다** — 저장소에 올리지 않고,
다시 필요하면 `tool/shoot_all_langs.py` 로 언제든 다시 찍을 수 있다.
"""
import io, os, shutil, sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "store", "screenshots")
DST = os.path.join(ROOT, "store", "업로드", "스크린샷")

# 1080×2400 기준. 상태바 약 75px, 내비게이션 바 약 130px
TOP, BOTTOM = 75, 130

KEEP_RAW = "--keep-raw" in sys.argv


def crop_dir(src, dst):
    os.makedirs(dst, exist_ok=True)
    n = 0
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png") or f.startswith("_"):
            continue
        im = Image.open(os.path.join(src, f)).convert("RGB")
        w, h = im.size
        im = im.crop((0, TOP, w, h - BOTTOM))
        im = im.convert("P", palette=Image.ADAPTIVE, colors=256)
        im.save(os.path.join(dst, f), optimize=True)
        n += 1
    return n


def main():
    if not os.path.isdir(SRC):
        print("찍은 화면이 없다:", SRC)
        return
    total = 0
    for lang in sorted(os.listdir(SRC)):
        d = os.path.join(SRC, lang)
        if not os.path.isdir(d):
            continue
        n = crop_dir(d, os.path.join(DST, lang))
        total += n
        print(f"  {lang}: {n}장")
    print(f"다듬은 화면 {total}장 → {DST}")

    if not KEEP_RAW:
        shutil.rmtree(SRC)
        print("원본 삭제 (다시 필요하면 tool/shoot_all_langs.py 로 재촬영)")


if __name__ == "__main__":
    main()
