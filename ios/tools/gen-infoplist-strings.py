"""안드로이드 res/values*/strings.xml 의 app_name 을 <언어>.lproj/InfoPlist.strings 로 옮긴다.

홈 화면 이름도 안드로이드 한 벌만 원본으로 둔다. 빌드 단계(copy-assets.sh)가 부른다.
    python3 gen-infoplist-strings.py <res 폴더> <번들 폴더>
"""
import os
import re
import sys

# 안드로이드 values 폴더 접미사 → 아이폰 lproj 이름
LPROJ = {
    "": "en", "ko": "ko", "ja": "ja", "zh": "zh-Hans", "zh-rTW": "zh-Hant", "zh-rHK": "zh-HK",
    "es": "es", "pt": "pt", "de": "de", "fr": "fr", "ru": "ru",
    "in": "id", "vi": "vi", "th": "th",
}

# 말하기 연습의 권한 설명 — 안드로이드에는 없는 아이폰 전용 문구라 여기 둔다
PERMS = {
    "en": ("The microphone is used only while you practice speaking, to check your English pronunciation.",
           "Speech recognition turns what you say into text so the app can check your speaking answer."),
    "ko": ("말하기 연습을 할 때만 마이크로 영어 발음을 들어요.", "말한 내용을 글자로 바꿔 말하기 답을 채점해요."),
    "ja": ("スピーキング練習のときだけ、マイクで英語の発音を聞き取ります。", "話した内容を文字にして、スピーキングの答えを採点します。"),
    "zh-Hans": ("仅在练习口语时使用麦克风来检查英语发音。", "语音识别会把你说的话转成文字，用来评判口语答案。"),
    "zh-Hant": ("僅在練習口說時使用麥克風來檢查英語發音。", "語音辨識會把你說的話轉成文字，用來評分口說答案。"),
    "zh-HK": ("僅在練習口說時使用麥克風來檢查英語發音。", "語音辨識會把你說的話轉成文字，用來評分口說答案。"),
    "es": ("El micrófono solo se usa mientras practicas la expresión oral, para revisar tu pronunciación en inglés.",
           "El reconocimiento de voz convierte lo que dices en texto para corregir tu respuesta oral."),
    "fr": ("Le micro n'est utilisé que pendant l'entraînement à l'oral, pour vérifier ta prononciation anglaise.",
           "La reconnaissance vocale transforme ce que tu dis en texte pour corriger ta réponse orale."),
    "de": ("Das Mikrofon wird nur beim Sprechtraining genutzt, um deine englische Aussprache zu prüfen.",
           "Die Spracherkennung wandelt das Gesagte in Text um, damit deine Sprechantwort bewertet werden kann."),
    "pt": ("O microfone é usado só durante a prática de fala, para verificar sua pronúncia em inglês.",
           "O reconhecimento de fala transforma o que você diz em texto para corrigir sua resposta oral."),
    "ru": ("Микрофон используется только во время разговорной практики, чтобы проверить английское произношение.",
           "Распознавание речи превращает сказанное в текст, чтобы проверить устный ответ."),
    "vi": ("Micro chỉ được dùng khi bạn luyện nói để kiểm tra phát âm tiếng Anh.",
           "Nhận dạng giọng nói chuyển lời bạn nói thành chữ để chấm câu trả lời nói."),
    "id": ("Mikrofon hanya dipakai saat latihan berbicara untuk memeriksa pelafalan bahasa Inggris.",
           "Pengenalan suara mengubah ucapanmu menjadi teks untuk menilai jawaban berbicara."),
    "th": ("ใช้ไมโครโฟนเฉพาะตอนฝึกพูด เพื่อตรวจการออกเสียงภาษาอังกฤษ",
           "การรู้จำเสียงพูดจะแปลงคำพูดเป็นข้อความเพื่อตรวจคำตอบการพูด"),
}

res, out = sys.argv[1], sys.argv[2]
for suffix, lproj in LPROJ.items():
    path = os.path.join(res, "values" + ("-" + suffix if suffix else ""), "strings.xml")
    if not os.path.exists(path):
        continue
    text = open(path, encoding="utf-8").read()
    m = re.search(r'<string name="app_name">(.*?)</string>', text)
    if not m:
        sys.exit(f"app_name 이 없음: {path}")
    name = m.group(1).replace("\\'", "'").replace('"', '\\"')
    lines = [f'"CFBundleDisplayName" = "{name}";', f'"CFBundleName" = "{name}";']
    mic, speech = PERMS[lproj]
    lines.append(f'"NSMicrophoneUsageDescription" = "{mic}";')
    lines.append(f'"NSSpeechRecognitionUsageDescription" = "{speech}";')
    d = os.path.join(out, lproj + ".lproj")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "InfoPlist.strings"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
