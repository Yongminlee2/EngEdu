/**
 * tools/i18n/strings.js 의 원장을 읽어 언어별 strings.xml 12개를 만든다.
 *
 *   node tools/i18n/gen_strings.js
 *
 * 기본(values/)은 영어 — 지원하지 않는 언어의 폰은 여기로 떨어진다.
 * 번역이 비어 있는 항목도 영어로 채워서, 화면에 빈칸이 뜨는 일이 없게 한다.
 */
const fs = require("fs");
const path = require("path");
const { langs, strings } = require("./strings");
const tplKo = require("./templates.json");          // 뼈대 원문 (한국어)
const tplTr = require("./templates_i18n");          // 뼈대 번역
const wordTr = require("./words_i18n");             // 인자·라벨에 박힌 낱말 번역
const unitTr = require("./units_i18n");             // 답 옆 단위 (개·명·원 …)
const arrays = require("./arrays");                 // 순서 있는 묶음 (요일 등)
const { derivedFrom } = require("./zh_trad");       // 번체 중국어는 간체에서 만들어 낸다

const RES = path.join(__dirname, "..", "..", "app", "src", "main", "res");

/**
 * 이 언어의 값을 고른다. 없으면 **영어로 떨어진다.**
 *
 * 번체 중국어(zh-rTW·zh-rHK)는 원장에 따로 쓰지 않는다 —
 * 간체(zh)에서 자동 변환한다. 간체를 고치면 번체도 같이 따라온다.
 */
function pick(byLang, lang) {
  const own = byLang[lang];
  if (own != null && own !== "") return own;
  const d = derivedFrom(lang);
  if (d) {
    const base = byLang[d.base];
    if (base != null && base !== "") return d.fn(base);
  }
  return null;                    // 부르는 쪽이 영어로 떨어뜨린다
}

/** XML 특수문자 + 안드로이드가 삼키는 문자 처리 */
function esc(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/'/g, "\\'")
    .replace(/"/g, "\\\"")
    .replace(/\n/g, "\\n");
}

let missing = 0;
for (const lang of langs) {
  const dir = path.join(RES, lang === "en" ? "values" : "values-" + lang);
  fs.mkdirSync(dir, { recursive: true });

  const lines = [
    '<?xml version="1.0" encoding="utf-8"?>',
    "<!-- 자동 생성: node tools/i18n/gen_strings.js — 직접 고치지 말 것 -->",
    "<resources>",
  ];
  for (const [key, byLang] of Object.entries(strings)) {
    let v = pick(byLang, lang);
    if (v == null) {
      v = byLang.en;             // 번역이 없으면 영어로 (빈칸 방지)
      if (lang !== "en") missing++;
    }
    lines.push(`    <string name="${key}">${esc(v)}</string>`);
  }

  // ---- 순서 있는 묶음 (요일 등) ----
  for (const [name, byLang] of Object.entries(arrays)) {
    let items = byLang[lang];
    if (!items) {
      const d = derivedFrom(lang);
      if (d && byLang[d.base]) items = byLang[d.base].map(d.fn);
    }
    if (!items) items = byLang.en;
    lines.push(`    <string-array name="${name}">`);
    for (const it of items) lines.push(`        <item>${esc(it)}</item>`);
    lines.push("    </string-array>");
  }

  // ---- 문제 뼈대 (tpl_*) ----
  // 한국어 폰은 팩 원문을 그대로 쓰므로 넣지 않는다 (앱 용량 낭비).
  // 영어에 없는 뼈대는 어느 언어에도 넣지 않는다 — 그래야 리소스를 못 찾고
  // 한국어 원문으로 안전하게 떨어진다(반쪽 번역이 섞이는 걸 막는다).
  if (lang !== "ko") {
    lines.push("", "    <!-- 문제·해설 뼈대 -->");
    for (const [key, byLang] of Object.entries(tplTr)) {
      if (!byLang.en) continue;
      if (!tplKo[key]) continue;                    // 생성기에서 사라진 뼈대
      const v = pick(byLang, lang) || byLang.en;
      lines.push(`    <string name="tpl_${key}">${esc(v)}</string>`);
    }

    // ---- 인자·라벨 낱말 사전 ----
    lines.push("", "    <!-- 문제 속 낱말 (사과·쿠키·삼각형 …) -->", '    <string-array name="tpl_words">');
    for (const [ko, byLang] of Object.entries(wordTr)) {
      if (byLang.en == null) continue;   // 빈 번역("")은 일부러 지우는 것이라 허용
      lines.push(`        <item>${esc(ko + "|" + (pick(byLang, lang) ?? byLang.en))}</item>`);
    }
    lines.push("    </string-array>");
    lines.push('    <string-array name="tpl_units">');
    for (const [ko, byLang] of Object.entries(unitTr)) {
      if (byLang.en == null) continue;
      lines.push(`        <item>${esc(ko + "|" + (pick(byLang, lang) ?? byLang.en))}</item>`);
    }
    lines.push("    </string-array>");
  }

  lines.push("</resources>", "");
  fs.writeFileSync(path.join(dir, "strings.xml"), lines.join("\n"), "utf8");
}

const n = Object.keys(strings).length;
const nTpl = Object.values(tplTr).filter((v) => v.en).length;
const nWord = Object.values(wordTr).filter((v) => v.en != null).length;
console.log(`언어 ${langs.length}종 × UI 문자열 ${n}개 생성`);
console.log(`문제 뼈대 ${nTpl}/${Object.keys(tplKo).length}종 · 낱말 ${nWord}개`);
console.log(missing === 0 ? "UI 번역 누락 없음" : `UI에서 영어로 대체된 항목: ${missing}개`);

// 뼈대 번역의 서식(%n$s) 개수가 원문과 다르면 앱에서 문장이 깨진다 — 여기서 잡는다
let bad = 0;
const slots = (s) => new Set((s.match(/%\d+\$s/g) || [])).size;

// 영어가 없으면 다른 언어도 기댈 곳이 없다 — 그 문장은 한국어로 떨어진다.
// "번역이 없으면 영어" 규칙을 지키려면 영어만큼은 반드시 있어야 한다.
for (const key of Object.keys(tplKo)) {
  if (!tplTr[key] || !tplTr[key].en) {
    console.log(`  ⚠ 영어 번역 없음: tpl_${key} — "${tplKo[key].ko.slice(0, 50)}"`);
    bad++;
  }
}

for (const [key, byLang] of Object.entries(tplTr)) {
  const src = tplKo[key];
  if (!src) { console.log(`  ⚠ 없는 뼈대: ${key}`); bad++; continue; }
  const want = slots(src.ko);
  for (const [lg, v] of Object.entries(byLang)) {
    if (slots(v) !== want) {
      console.log(`  ⚠ ${key}(${lg}) 자리값 ${slots(v)}개 — 원문은 ${want}개`);
      bad++;
    }
  }
}
if (bad) { console.error(`서식 불일치 ${bad}건 — 고치기 전에는 배포 금지`); process.exit(1); }
for (const [name, byLang] of Object.entries(arrays)) {
  const n = byLang.en.length;
  for (const [lg, arr] of Object.entries(byLang)) {
    if (arr.length !== n) {
      console.error(`  ⚠ 배열 ${name}(${lg}) 개수 ${arr.length} — 영어는 ${n}개`);
      process.exit(1);
    }
  }
}
console.log("뼈대 서식 · 배열 개수 검사 통과");
