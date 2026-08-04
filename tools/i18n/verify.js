/**
 * 앱이 하는 조립을 그대로 흉내 내어 **번역 결과를 전수 검사한다.**
 *
 *   node tools/i18n/verify.js         # 전 언어
 *   node tools/i18n/verify.js en      # 한 언어만
 *
 * 잡아내는 것
 *  1) 번역했는데도 화면에 한국어가 남는 문제 (사전에 없는 낱말)
 *  2) %n$s 자리에 넣을 값이 모자라거나 남는 경우
 *  3) 뼈대는 있는데 번역이 없어 한국어로 떨어지는 문제
 *
 * 이 검사를 통과해야 "12개 언어 지원"이라고 말할 수 있다.
 */
const fs = require("fs");
const path = require("path");

const PACKS = path.join(__dirname, "..", "..", "app", "src", "main", "assets", "packs");
const tplTr = require("./templates_i18n");
const wordTr = require("./words_i18n");
const unitTr = require("./units_i18n");
const { langs } = require("./strings");

const only = process.argv[2];
const targets = only ? [only] : langs.filter((l) => l !== "ko");

const HANGUL_RUN = /[가-힣]+/g;

function makeDict(src, lang) {
  const m = new Map();
  for (const [ko, by] of Object.entries(src)) {
    if (by.en == null) continue;
    m.set(ko, by[lang] == null ? by.en : by[lang]);
  }
  return m;
}

/** Tpl.word() 와 같은 규칙: 통짜 구절 먼저, 없으면 낱말 단위 */
function word(s, dict) {
  if (!s) return s;
  if (dict.has(s)) return dict.get(s);
  const t = s.trim();
  if (t.length !== s.length && dict.has(t)) return s.replace(t, dict.get(t));
  if (s.includes("\n")) return s.split("\n").map((l) => word(l, dict)).join("\n");
  return s.replace(HANGUL_RUN, (w) => (dict.has(w) ? dict.get(w) : w));
}

/** 안드로이드 getString(id, args...) 흉내 */
function format(tpl, args) {
  let missing = false;
  const out = tpl.replace(/%(\d+)\$s|%%/g, (m, n) => {
    if (m === "%%") return "%";
    const v = args[Number(n) - 1];
    if (v === undefined) { missing = true; return m; }
    return v;
  });
  return { out, missing };
}

const questions = [];
for (const f of fs.readdirSync(PACKS)) {
  if (!f.endsWith(".json")) continue;
  const j = JSON.parse(fs.readFileSync(path.join(PACKS, f), "utf8"));
  (function walk(o) {
    if (Array.isArray(o)) return o.forEach(walk);
    if (o && typeof o === "object") {
      if (o.type === "math") questions.push(o);
      Object.values(o).forEach(walk);
    }
  })(j);
}

let failed = 0;
for (const lang of targets) {
  const wd = makeDict(wordTr, lang);
  const ud = makeDict(unitTr, lang);
  const leftover = new Map();      // 남은 한글 → 예시
  const noTrSample = new Map();    // 뼈대가 없어 한국어로 떨어지는 문장 → 예시
  let noTr = 0, badArgs = 0, done = 0;

  for (const q of questions) {
    for (const [kf, af, text] of [["tk", "ta", q.prompt], ["ek", "ea", q.explain]]) {
      if (!text) continue;
      const key = q[kf];
      const short = () => text.replace(/\n/g, " ").slice(0, 80);
      if (!key) {
        // 뼈대 키가 없다 = 이 문장은 어떤 언어에서도 한국어로 나온다
        if (/[가-힣]/.test(text) && !noTrSample.has(short())) {
          noTr++; noTrSample.set(short(), q.id);
        } else if (/[가-힣]/.test(text)) noTr++;
        continue;
      }
      const by = tplTr[key];
      if (!by || !by.en) {
        // 영어 번역이 없으면 나머지 언어도 기댈 곳이 없다 → 한국어로 떨어진다
        noTr++;
        if (!noTrSample.has(short())) noTrSample.set(short(), key);
        continue;
      }
      const tpl = by[lang] == null ? by.en : by[lang];
      const args = (q[af] || []).map((a) => word(String(a), wd));
      const { out, missing } = format(tpl, args);
      if (missing) badArgs++;
      done++;
      for (const w of out.match(HANGUL_RUN) || []) {
        if (!leftover.has(w)) leftover.set(w, out.replace(/\n/g, " ").slice(0, 90));
      }
    }
    if (q.unit && /[가-힣]/.test(word(String(q.unit), ud))) {
      leftover.set("(단위)" + q.unit, "단위 " + q.unit);
    }
    for (const c of q.choices || []) {
      const t = word(String(c), wd);
      for (const w of t.match(HANGUL_RUN) || []) if (!leftover.has(w)) leftover.set(w, "선택지 " + t);
    }
    for (const l of (q.visual && q.visual.labels) || []) {
      const t = word(String(l), wd);
      for (const w of t.match(HANGUL_RUN) || []) if (!leftover.has(w)) leftover.set(w, "그림 라벨 " + t);
    }
  }

  // 셋 다 0이어야 한다. 하나라도 남으면 그 폰에는 한국어가 그대로 뜬다
  const ok = leftover.size === 0 && badArgs === 0 && noTr === 0;
  if (!ok) failed++;
  console.log(`[${lang}] 조립 ${done}건 · 뼈대없음 ${noTr} · 자리값오류 ${badArgs} · 한글잔여 ${leftover.size}종 ${ok ? "✔" : "✘"}`);
  for (const [w, sample] of [...leftover].slice(0, 12)) console.log(`      한글잔여: ${w}  ← ${sample}`);
  for (const [t, where] of [...noTrSample].slice(0, 12)) console.log(`      뼈대없음(${where}): ${t}`);
}

if (failed === 0) {
  console.log("\n전 언어 통과 — 어느 폰에서도 한국어가 새어 나오지 않는다");
  process.exit(0);
}
console.error(`\n${failed}개 언어에서 한국어가 그대로 뜬다.`);
console.error("고치는 법: 해당 문장을 tp(\"?\", [값들], `원문`) 으로 감싸고");
console.error("  node tools/i18n/keyify.js --write → tools/i18n/tpl/ 에 영어부터 번역을 넣는다.");
process.exit(1);
