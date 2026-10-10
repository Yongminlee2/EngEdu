#!/usr/bin/env python3
"""시뮬레이터에서 여러 화면을 실행 인자로 띄워 찍고 한 장으로 붙인다(확인용).
    DEVICE=<udid> python3 tools/shots.py <출력폴더> "이름|-shot lesson -track math_g1 -lesson ml133" ...
"""
import os, subprocess, sys, time
from PIL import Image

dev = os.environ.get("DEVICE", "booted")
bundle = os.environ.get("BUNDLE", "com.peep.english")
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
files = []
for spec in sys.argv[2:]:
    name, args = spec.split("|", 1)
    subprocess.run(["xcrun", "simctl", "terminate", dev, bundle], capture_output=True)
    time.sleep(1.5)
    subprocess.run(["xcrun", "simctl", "launch", dev, bundle] + args.split(), capture_output=True)
    time.sleep(float(os.environ.get("WAIT", "4")))
    f = os.path.join(out, name + ".png")
    subprocess.run(["xcrun", "simctl", "io", dev, "screenshot", f], capture_output=True)
    files.append(f)
w, h = 268, 582
for part in range(0, len(files), 8):
    ims = [Image.open(f).convert("RGB").resize((w, h)) for f in files[part:part + 8]]
    sheet = Image.new("RGB", (w * len(ims), h), "white")
    for i, im in enumerate(ims):
        sheet.paste(im, (w * i, 0))
    sheet.save(os.path.join(out, f"_sheet{part // 8}.png"))
print(len(files))
