#!/usr/bin/env python3
"""안드로이드 engine/WordArt.kt(낱말 → 그림 이름 표)를 아이폰 Gen/WordArt.swift 로 옮긴다.

WordArt.kt 자체가 tools/gen_wordart.js 의 생성물이다. 안드로이드에서 그것을 다시 만들었으면 이것도 돌린다.
    python3 tools/gen-wordart.py      (ios/ 에서)
시험(WordArtParityTests)이 두 표가 같은지 본다.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
IOS = os.path.dirname(HERE)
SRC = os.path.join(IOS, "..", "app", "src", "main", "java", "com", "piyak", "english", "engine", "WordArt.kt")
OUT = os.path.join(IOS, "PeepEnglish", "Gen", "WordArt.swift")

text = open(SRC, encoding="utf-8").read()
blocks = {}
for name in ("EN", "KO"):
    m = re.search(r"val %s: Map<String, String> = mapOf\((.*?)\n    \)" % name, text, re.S)
    blocks[name] = re.findall(r'"((?:[^"\\]|\\.)*)" to "((?:[^"\\]|\\.)*)"', m.group(1))

out = ["// 자동 생성: tools/gen-wordart.py — 직접 고치지 말 것 (안드로이드 engine/WordArt.kt 에서 만든다)", "",
       "/// 낱말 그림 사전 색인. EN: 영어 단어 → 그림 이름 / KO: 한글 뜻 → 그림 이름", "enum WordArt {"]
for name, pairs in blocks.items():
    # 큰 사전 글자값은 스위프트 형 추론이 느리다 — 두 배열로 두고 처음 쓸 때 사전으로 만든다
    out.append(f"    private static let {name.lower()}Keys: [String] = [")
    out += [f'        "{k}",' for k, _ in pairs]
    out.append("    ]")
    out.append(f"    private static let {name.lower()}Values: [String] = [")
    out += [f'        "{v}",' for _, v in pairs]
    out.append("    ]")
    out.append(f"    static let {name}: [String: String] = Dictionary(uniqueKeysWithValues: zip({name.lower()}Keys, {name.lower()}Values))")
out.append("}")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
print({k: len(v) for k, v in blocks.items()})
