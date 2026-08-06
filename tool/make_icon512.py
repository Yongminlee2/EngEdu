# -*- coding: utf-8 -*-
"""스토어 아이콘 512 를 다시 만든다 — 병아리가 타일을 꽉 채우게.

**앞서 틀린 것**: 어댑티브 아이콘 원본(`ic_launcher_fg`)은 런처가 가장자리를 잘라내는 것을
전제로 **이미 넉넉한 여백을 품고 있다**(그림이 가로 47%만 차지). 거기에 다시 72% 로 줄여
얹었더니 가로 33% 짜리 콩알 병아리가 됐다. 폰에서는 런처가 가운데를 확대해 보여 주므로
꽉 차 보여서 눈치채기 어려웠고, 스토어 목록에서만 티가 났다.

**고친 방식**: 원본 여백이 얼마든 상관없이, **그림의 실제 범위를 재서** 목표 비율까지
키운다. 삐약푸쉬 아이콘(가로 83%)과 같은 인상이 되도록 맞췄다.
"""
import io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image

# 삐약푸쉬가 가로 83% · 세로 72% 다. 같은 정도로 채운다.
TARGET = 0.82          # 긴 쪽이 타일의 몇 할을 차지할지
APPS = [("PiyakEnglish", "cream")]


def color_of(app, name):
    p = f"C:/workAndroid/{app}/app/src/main/res/values/colors.xml"
    s = io.open(p, encoding="utf-8").read()
    m = re.search(r'name="%s">\s*(#[0-9A-Fa-f]{6,8})' % re.escape(name), s)
    assert m, f"{app}: {name} 색 없음"
    h = m.group(1).lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


for app, bg_name in APPS:
    root = f"C:/workAndroid/{app}"
    bg = color_of(app, bg_name)

    fg = Image.open(f"{root}/app/src/main/res/mipmap-xxxhdpi/ic_launcher_fg.png").convert("RGBA")
    box = fg.getchannel("A").getbbox()          # 그림이 실제로 있는 범위
    art = fg.crop(box)

    # 긴 쪽을 목표 비율에 맞춰 키운다 (원본 여백이 얼마든 결과가 같아진다)
    scale = (512 * TARGET) / max(art.width, art.height)
    art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))),
                     Image.LANCZOS)

    canvas = Image.new("RGB", (512, 512), bg)
    canvas.paste(art, ((512 - art.width) // 2, (512 - art.height) // 2), art)

    out = f"{root}/store/업로드/icon_512.png"
    canvas.save(out, optimize=True)
    print(f"  {app}: 그림 {art.width}×{art.height} "
          f"= 가로 {art.width / 512 * 100:.0f}% 세로 {art.height / 512 * 100:.0f}% (배경 {bg})")
