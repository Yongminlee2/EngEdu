# -*- coding: utf-8 -*-
"""14개 언어의 스토어 스크린샷을 폰에서 자동으로 찍는다 (삐약영어).

    python tool/shoot_all_langs.py          # 전부
    python tool/shoot_all_langs.py ja ru    # 지정한 언어만

폰이 연결돼 있어야 하고, 앱이 설치돼 있어야 한다.
결과: store/screenshots/<언어코드>/01_home.png ...

**언어는 앱별 언어 설정(adb)으로 바꾼다.**
삐약푸쉬는 앱 안의 언어 목록을 두드려야 했지만, 이 앱은 안드로이드 13+의 앱별 언어를
지원하므로 `cmd locale set-app-locales` 한 줄로 끝난다 — 목록을 스크롤하며 좌표를 세는
것보다 훨씬 덜 깨진다.

**좌표는 화면 아래에서 잰다.** 홈을 끝까지 밀어 내리면 아래쪽 요소(지갑·레벨테스트·
오답/통계/설정)의 위치가 언어와 상관없이 같다. 위쪽은 번역 길이에 따라 카드 높이가
달라져 어긋난다 — 실제로 러시아어에서 그렇게 어긋났다.
"""
import io, os, subprocess, sys, time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADB = r"C:\Users\사용자\AppData\Local\Android\Sdk\platform-tools\adb.exe"
PKG = "com.peep.english"
ACT = f"{PKG}/com.piyak.english.ui.MainActivity"
OUT = os.path.join(ROOT, "store", "screenshots")

LANGS = ["ko", "en", "ja", "zh", "zh_Hant", "zh_HK", "es", "fr",
         "de", "pt", "ru", "th", "vi", "id"]

# adb 에 넘길 BCP-47 태그 (폴더 이름과 다른 것들)
TAG = {"zh": "zh-CN", "zh_Hant": "zh-TW", "zh_HK": "zh-HK", "id": "id-ID",
       "ko": "ko-KR", "en": "en-US", "ja": "ja-JP", "es": "es-ES", "fr": "fr-FR",
       "de": "de-DE", "pt": "pt-BR", "ru": "ru-RU", "th": "th-TH", "vi": "vi-VN"}

# ── 화면 아래 기준 좌표 (1080×2400)
BTN_WRONG = (199, 2164)     # 오답 노트
BTN_STATS = (540, 2164)     # 통계
WALLET = (540, 1698)        # 지갑 배너
BTN_CHECK = (540, 2168)     # 확인
BTN_CONTINUE = (540, 2159)  # 계속하기

# 보기 버블 자리. 문제 유형마다 높이가 다르다 — 그림 문제와 듣기 문제(재생 버튼이 한 줄 더
# 있어 아래로 밀린다)를 모두 덮도록 두 벌을 둔다.
CHOICES = [
    # 버블(짧은 보기) — 그림 문제와 듣기 문제로 두 벌
    (288, 1038), (786, 1038), (288, 1356), (786, 1356),
    (288, 1158), (786, 1158), (288, 1458), (786, 1458),
    # 목록 버튼(긴 보기). 보기 글자가 길면 앱이 버블 대신 가로로 긴 버튼을 쓴다 —
    # 베트남어처럼 낱말이 긴 언어에서 이 모양이 나온다.
    (540, 1072), (540, 1219), (540, 1366), (540, 1512),
]


def sh(*a, binary=False):
    r = subprocess.run([ADB, *a], capture_output=True)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def shot(lang, name):
    d = os.path.join(OUT, lang)
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, name + ".png"), "wb").write(sh("exec-out", "screencap", "-p", binary=True))


def tap(x, y, wait=1.6):
    sh("shell", "input", "tap", str(x), str(y)); time.sleep(wait)


def back(wait=1.5):
    sh("shell", "input", "keyevent", "4"); time.sleep(wait)


def to_bottom(n=5):
    for _ in range(n):
        sh("shell", "input", "swipe", "540", "1800", "540", "500", "250")
    time.sleep(1.0)


def panel_is_correct(png_bytes):
    """정답이면 True, 오답이면 False, 패널이 안 떴으면 None.

    **계속하기 버튼 색**으로 가른다 — 정답은 진한 초록(#66BB6A), 오답은 진한 빨강(#FF5252).
    옅은 패널 바탕을 보면 크림색 배경과 헷갈려 "패널 없음"으로 오판하고, 한 번 오판하면
    그 뒤로 계속 헛돈다 (실제로 11개 언어가 그렇게 실패했다).
    """
    from PIL import Image
    import io as _io
    im = Image.open(_io.BytesIO(png_bytes)).convert("RGB")
    w, h = im.size
    # 버튼 높이는 해설 길이에 따라 조금 오르내리므로 몇 줄을 훑는다
    for frac in (0.900, 0.912, 0.888, 0.925, 0.875):
        r, g, b = im.getpixel((w // 2, int(h * frac)))
        if g > r + 40 and g > b + 40:
            return True
        if r > g + 60 and r > b + 60:
            return False
    return None


def answer_until_correct(lang, rounds=12):
    """정답을 맞힐 때까지 문제를 넘겨 가며 눌러 본다. 스토어에는 초록 화면이 낫다.

    보기를 눌러도 선택이 안 되는 경우가 있어(유형마다 버블 높이가 다르다)
    **한 문제 안에서 자리를 바꿔 가며** 눌러 본다.
    """
    pos = 0
    for _ in range(rounds):
        ok, png = None, None
        for _ in range(len(CHOICES)):
            tap(*CHOICES[pos % len(CHOICES)], wait=0.9)
            pos += 1
            tap(*BTN_CHECK, wait=2.0)
            png = sh("exec-out", "screencap", "-p", binary=True)
            ok = panel_is_correct(png)
            if ok is not None:
                break
        if ok:
            d = os.path.join(OUT, lang)
            os.makedirs(d, exist_ok=True)
            open(os.path.join(d, "07_answer.png"), "wb").write(png)
            return True
        if ok is False:
            tap(*BTN_CONTINUE, wait=1.8)   # 계속하기 → 다음 문제
        else:
            break                          # 문제 화면이 아니다 — 더 해봐야 소용없다
    shot(lang, "07_answer")
    print(f"    ⚠ {lang}: 정답 화면을 못 얻어 마지막 화면으로 대체")
    return False


def shoot(lang):
    sh("shell", "cmd", "locale", "set-app-locales", PKG, "--locales", TAG[lang])
    sh("shell", "am", "force-stop", PKG)
    time.sleep(1.0)
    sh("shell", "am", "start", "-n", ACT)
    time.sleep(4.5)

    shot(lang, "01_home")            # 홈 위 — 배너·병아리·학습 코스

    to_bottom()
    shot(lang, "02_skills")          # 실력 대시보드 · 지갑 · 레벨테스트

    tap(*WALLET, wait=2.5)
    shot(lang, "03_wallet")          # 지갑과 상점
    back()

    to_bottom()
    tap(*BTN_STATS, wait=3.0)
    shot(lang, "04_stats")           # 통계 달력
    for _ in range(5):
        sh("shell", "input", "swipe", "540", "1800", "540", "400", "220")
    time.sleep(1.0)
    shot(lang, "05_badges")          # 배지
    back()

    to_bottom()
    tap(*BTN_WRONG, wait=3.5)
    shot(lang, "06_question")        # 문제 화면
    answer_until_correct(lang)       # 07_answer

    # 레슨을 빠져나온다 (✕ → 그만두기)
    tap(76, 119, wait=1.5)
    tap(880, 1396, wait=2.0)
    print(f"  {lang} 7장")


def answer_ok(lang):
    """그 언어의 07_answer 가 정답(초록) 화면인가."""
    from PIL import Image
    p = os.path.join(OUT, lang, "07_answer.png")
    if not os.path.exists(p):
        return False
    im = Image.open(p).convert("RGB")
    w, h = im.size
    for frac in (0.900, 0.912, 0.888, 0.925, 0.875):
        r, g, b = im.getpixel((w // 2, int(h * frac)))
        if g > r + 40 and g > b + 40:
            return True
    return False


def main():
    want = sys.argv[1:] or LANGS
    failed = []
    for lang in want:
        if lang not in TAG:
            print("  모르는 언어:", lang); continue
        # **한 언어가 끝날 때마다 바로 검증한다.** 14개를 다 돌린 뒤에야 실패를 알면
        # 처음부터 다시 돌려야 한다 — 실제로 그렇게 두 번 날렸다.
        for attempt in (1, 2, 3):
            shoot(lang)
            if answer_ok(lang):
                break
            print(f"    ↻ {lang}: 정답 화면 실패 — 다시 ({attempt}/3)")
        else:
            failed.append(lang)
    if failed:
        print("  ⚠ 끝내 실패:", failed)
    sh("shell", "cmd", "locale", "set-app-locales", PKG, "--locales", "")
    print("언어 설정 원복 완료")


if __name__ == "__main__":
    main()
