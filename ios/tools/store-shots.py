#!/usr/bin/env python3
"""앱스토어 스크린샷 (6.3인치 1206×2622, iPhone 17 Pro 시뮬레이터) — 언어별 8장.

    DEVICE=<udid> python3 tools/store-shots.py [언어 ...]
결과: ios/build/store-shots/<언어>/01_home.png …  (저장소 밖 build/ 아래)
화면은 DEBUG 실행 인자로 띄운다(시뮬레이터에 탭을 넣을 수 없는 맥이라서).
안드로이드 tool/shoot_all_langs.py 의 7장에 알파벳 쓰기 한 장을 더했다.
"""
import os, subprocess, sys, time

DEV = os.environ.get("DEVICE", "booted")
BUNDLE = os.environ.get("BUNDLE", "com.peep.english")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "build", "store-shots")

# 앱스토어 언어 → 기기 언어
LANGS = {"ko": "ko-KR", "en": "en-US", "ja": "ja-JP", "zh-Hans": "zh-Hans-CN", "zh-Hant": "zh-Hant-TW",
         "es": "es-ES", "fr": "fr-FR", "de": "de-DE", "pt": "pt-BR", "ru": "ru-RU", "th": "th-TH",
         "vi": "vi-VN", "id": "id-ID"}

SHOTS = [
    ("01_home", "-shot main"),
    ("02_skills", "-shot main -scroll bottom"),
    ("03_wallet", "-shot wallet"),
    ("04_stats", "-shot stats"),
    ("05_badges", "-shot stats -scroll bottom"),
    ("06_question", "-shot lesson -track basic -lesson ls1"),
    ("07_answer", "-shot lesson -track basic -lesson ls1 -answer 1"),
    ("08_alphabet", "-shot trace -index 0 -upper true"),
]
if os.environ.get("SHOTS"):
    SHOTS = [tuple(x.split("|", 1)) for x in os.environ["SHOTS"].split(";")]

def run(*a):
    return subprocess.run(["xcrun", "simctl", *a], capture_output=True, text=True)

run("status_bar", DEV, "override", "--time", "9:41", "--dataNetwork", "wifi", "--wifiBars", "3",
    "--cellularMode", "active", "--cellularBars", "4", "--batteryState", "charged", "--batteryLevel", "100")

langs = sys.argv[1:] or list(LANGS)
for lang in langs:
    loc = LANGS[lang]
    d = os.path.join(OUT, lang)
    os.makedirs(d, exist_ok=True)
    for name, args in SHOTS:
        f = os.path.join(d, name + ".png")
        for attempt in range(3):
            # 같은 맥의 다른 작업이 시뮬레이터를 꺼 버릴 때가 있다 — 꺼져 있으면 다시 켠다
            if "Booted" not in run("list", "devices", DEV).stdout:
                run("boot", DEV); run("bootstatus", DEV, "-b")
            run("terminate", DEV, BUNDLE)
            time.sleep(1.2)
            run("launch", DEV, BUNDLE, *args.split(), "-AppleLanguages", f"({loc})", "-AppleLocale", loc.replace("-", "_"))
            time.sleep(float(os.environ.get("WAIT", "4")))
            r = run("io", DEV, "screenshot", f)
            if r.returncode == 0 and os.path.exists(f) and os.path.getsize(f) > 100_000:
                break
            print("  다시", lang, name, flush=True)
    print(lang, "ok", flush=True)
