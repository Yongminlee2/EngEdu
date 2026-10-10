#!/usr/bin/env python3
"""안드로이드 res/ 에서 아이폰용 Gen/R.swift 와 Gen/Bindings.swift 를 만든다.

  python3 tools/gen-r.py            (ios/ 에서)

- R.swift      : R.string.x · R.drawable.x · R.id.x … 리소스 번호 (안드로이드처럼 Int)
- Bindings.swift : 레이아웃마다 ViewBinding 클래스 (ActivityMainBinding.inflate(...).txtGreeting)

안드로이드에서 문구·그림·레이아웃을 더하거나 지우면 다시 돌린다.
아이폰 시험(ResourceParityTests)이 res 와 R.swift 가 어긋나면 잡는다.
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
IOS = os.path.dirname(HERE)
ROOT = os.path.dirname(IOS)
RES = os.path.join(ROOT, "app", "src", "main", "res")
APP = sys.argv[1] if len(sys.argv) > 1 else next(
    d for d in os.listdir(IOS) if os.path.isdir(os.path.join(IOS, d, "Droid")))
OUT = os.path.join(IOS, APP, "Gen")
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"

# ResType 순서 — Droid/Res.swift 의 enum ResType 과 같아야 한다
TYPES = ["string", "array", "color", "dimen", "drawable", "mipmap", "layout", "id", "anim", "raw", "xml"]

SWIFT_KEYWORDS = {
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init", "inout",
    "internal", "let", "open", "operator", "private", "protocol", "public", "rethrows", "static", "struct",
    "subscript", "typealias", "var", "break", "case", "continue", "default", "defer", "do", "else", "fallthrough",
    "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while", "as", "Any", "catch", "false", "is",
    "nil", "super", "self", "Self", "throw", "throws", "true", "try", "some", "Type",
}


def ident(n):
    return f"`{n}`" if n in SWIFT_KEYWORDS else n


def collect():
    names = {t: set() for t in TYPES}
    vals = os.path.join(RES, "values")
    for f in os.listdir(vals):
        if not f.endswith(".xml"):
            continue
        root = ET.parse(os.path.join(vals, f)).getroot()
        for el in root:
            n = el.get("name")
            if not n:
                continue
            tag = {"string": "string", "string-array": "array", "color": "color", "dimen": "dimen"}.get(el.tag)
            if tag:
                names[tag].add(n)
    for d in os.listdir(RES):
        p = os.path.join(RES, d)
        if not os.path.isdir(p):
            continue
        base = d.split("-")[0]
        for f in os.listdir(p):
            stem = f.split(".")[0]
            if base == "drawable":
                names["drawable"].add(stem)
            elif base == "mipmap":
                names["mipmap"].add(stem)
            elif base == "layout":
                names["layout"].add(stem)
            elif base in ("anim", "raw", "xml"):
                if base == "raw" and stem == "keep":
                    continue
                names[base].add(stem)
    layouts = os.path.join(RES, "layout")
    for f in os.listdir(layouts):
        for m in re.finditer(r'@\+id/([A-Za-z0-9_]+)', open(os.path.join(layouts, f), encoding="utf-8").read()):
            names["id"].add(m.group(1))
    return {t: sorted(v) for t, v in names.items()}


def gen_r(names):
    out = ["// 자동 생성: tools/gen-r.py — 직접 고치지 말 것 (안드로이드 res/ 에서 만든다)", "", "enum R {"]
    for ti, t in enumerate(TYPES):
        out.append(f"    enum {t} {{")
        for i, n in enumerate(names[t]):
            out.append(f"        static let {ident(n)} = 0x{0x7f000000 | ((ti + 1) << 16) | i:08x}")
        out.append("    }")
    out.append("")
    out.append("    /// 번호 ↔ 이름 표를 Droid 에 알려 준다 (앱 시작 때 한 번)")
    out.append("    static func register() {")
    for t in TYPES:
        lst = ", ".join(f'"{n}"' for n in names[t])
        out.append(f"        ResNames.tables[.{t}] = [{lst}] as [String]")
    out.append("    }")
    out.append("}")
    return "\n".join(out) + "\n"


TAG_TYPES = {
    "LinearLayout": "LinearLayout", "FrameLayout": "FrameLayout", "ScrollView": "ScrollView",
    "androidx.core.widget.NestedScrollView": "ScrollView", "GridLayout": "GridLayout",
    "TextView": "TextView", "Button": "Button", "androidx.appcompat.widget.AppCompatButton": "Button",
    "com.google.android.material.button.MaterialButton": "Button", "ImageView": "ImageView",
    "ImageButton": "ImageView", "androidx.appcompat.widget.AppCompatImageView": "ImageView",
    "EditText": "EditText", "ProgressBar": "ProgressBar", "SeekBar": "SeekBar",
    "com.google.android.material.switchmaterial.SwitchMaterial": "CompoundButton",
    "androidx.appcompat.widget.SwitchCompat": "CompoundButton", "Switch": "CompoundButton", "CheckBox": "CompoundButton",
    "Space": "Space", "View": "View",
}


def swift_type(tag):
    if tag in TAG_TYPES:
        return TAG_TYPES[tag]
    return tag.split(".")[-1]


def camel(s):
    parts = s.split("_")
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def gen_bindings(names):
    out = ["// 자동 생성: tools/gen-r.py — 직접 고치지 말 것 (안드로이드 res/layout 에서 만든다)", ""]
    customs = set()
    for layout in names["layout"]:
        path = os.path.join(RES, "layout", layout + ".xml")
        root = ET.parse(path).getroot()
        cls = "".join(p[:1].upper() + p[1:] for p in layout.split("_")) + "Binding"
        fields = []
        for el in root.iter():
            if "." in el.tag and not el.tag.startswith(("androidx.", "com.google.")):
                customs.add(el.tag)
            vid = el.get(ANDROID_NS + "id")
            if vid and vid.startswith("@+id/"):
                n = vid[5:]
                if el is root:
                    continue
                fields.append((camel(n), n, swift_type(el.tag)))
        rtype = swift_type(root.tag)
        out.append(f"final class {cls} {{")
        out.append(f"    let root: {rtype}")
        for f, _, t in fields:
            out.append(f"    let {ident(f)}: {t}")
        out.append("")
        out.append("    private init(_ v: View) {")
        out.append(f"        root = v as! {rtype}")
        for f, n, t in fields:
            out.append(f"        {ident(f)} = v.findViewById(R.id.{ident(n)})!")
        out.append("    }")
        out.append(f"    static func inflate(_ inflater: LayoutInflater) -> {cls} {{")
        out.append(f"        {cls}(inflater.inflate(R.layout.{layout}, nil, false))")
        out.append("    }")
        out.append(f"    static func inflate(_ inflater: LayoutInflater, _ parent: ViewGroup?, _ attachToParent: Bool) -> {cls} {{")
        out.append(f"        {cls}(inflater.inflate(R.layout.{layout}, parent, attachToParent))")
        out.append("    }")
        out.append(f"    static func bind(_ v: View) -> {cls} {{ {cls}(v) }}")
        out.append("}")
        out.append("")
    out.append("enum Bindings {")
    out.append("    /// 레이아웃 XML 에 쓰인 직접 만든 부품")
    out.append("    static func registerCustomViews() {")
    for c in sorted(customs):
        out.append(f'        LayoutInflater.customViews["{c}"] = {{ {c.split(".")[-1]}($0, nil) }}')
    out.append("    }")
    out.append("}")
    return "\n".join(out) + "\n"


def main():
    names = collect()
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "R.swift"), "w", encoding="utf-8") as f:
        f.write(gen_r(names))
    with open(os.path.join(OUT, "Bindings.swift"), "w", encoding="utf-8") as f:
        f.write(gen_bindings(names))
    print("R.swift:", {t: len(v) for t, v in names.items()})


if __name__ == "__main__":
    main()
