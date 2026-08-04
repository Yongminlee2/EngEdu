/**
 * 번역이 **엉뚱한 언어 칸에 들어갔는지** 검사한다.
 *
 *   node tools/i18n/check_scripts.js
 *
 * 수천 개를 손으로 쓰다 보면 중국어 칸에 러시아어를 붙여 넣는 사고가 난다.
 * 눈으로는 절대 못 잡으므로 **글자 체계(script)** 로 기계가 본다.
 *   · 러시아어 칸에 키릴이 하나도 없다  → 의심
 *   · 중국어·일본어 칸에 한자/가나가 없다 → 의심
 *   · 반대로 그 언어에 있을 리 없는 글자가 섞였다 → 의심
 *
 * 숫자·기호만으로 된 짧은 문장(예: "%1$d")은 건너뛴다 — 정상이다.
 */
const strings = require("./strings").strings;
const tpl = require("./templates_i18n");
const words = require("./words_i18n");
const units = require("./units_i18n");
const arrays = require("./arrays");
const tplKo = require("./templates.json");

const HAS = {
  cyrillic: /[Ѐ-ӿ]/,
  hangul: /[가-힣]/,
  kana: /[぀-ヿ]/,
  han: /[一-鿿]/,
  thai: /[฀-๿]/,
  latin: /[A-Za-z]/,
};

/** 언어별로 "반드시 없어야 하는" 글자 체계 */
const FORBIDDEN = {
  en: ["cyrillic", "hangul", "kana", "thai"],
  ko: ["cyrillic", "kana", "thai"],
  ja: ["cyrillic", "hangul", "thai"],
  zh: ["cyrillic", "hangul", "kana", "thai"],
  es: ["cyrillic", "hangul", "kana", "han", "thai"],
  fr: ["cyrillic", "hangul", "kana", "han", "thai"],
  de: ["cyrillic", "hangul", "kana", "han", "thai"],
  pt: ["cyrillic", "hangul", "kana", "han", "thai"],
  ru: ["hangul", "kana", "han", "thai"],
  vi: ["cyrillic", "hangul", "kana", "han", "thai"],
  th: ["cyrillic", "hangul", "kana", "han"],
  in: ["cyrillic", "hangul", "kana", "han", "thai"],
};

/**
 * 그 언어라면 **적어도 하나는 있어야 하는** 글자 체계.
 * 일본어는 한자만으로 쓰는 수학 용어가 흔하다(二次関数) — 가나든 한자든 있으면 통과.
 */
const EXPECTED = {
  ru: ["cyrillic"], ko: ["hangul"], ja: ["kana", "han"], zh: ["han"], th: ["thai"],
};

let bad = 0;
const check = (where, key, lang, text, koSource) => {
  if (typeof text !== "string" || !text) return;
  for (const f of FORBIDDEN[lang] || []) {
    if (HAS[f].test(text)) {
      console.log(`  ✘ ${where} ${key} [${lang}] 에 ${f} 글자가 섞였다: ${text.slice(0, 60)}`);
      bad++;
      return;
    }
  }
  // 한국어 원문부터 글자가 없으면(순수 수식) 어느 언어에도 native script 를 기대할 수 없다
  if (koSource != null && !HAS.hangul.test(koSource)) return;
  // 라틴 문자는 수식 기호(x·y·D·cm)일 때가 많아 길이 계산에서 뺀다
  const want = EXPECTED[lang];
  const letters = text.replace(/[^\p{L}]/gu, "").replace(/[A-Za-z]/g, "");
  if (want && letters.length >= 6 && !want.some((w) => HAS[w].test(text))) {
    console.log(`  ? ${where} ${key} [${lang}] 에 ${want.join("/")} 글자가 없다: ${text.slice(0, 60)}`);
    bad++;
  }
};

for (const [k, byLang] of Object.entries(strings)) {
  for (const [lg, v] of Object.entries(byLang)) check("UI", k, lg, v, byLang.ko);
}
for (const [k, byLang] of Object.entries(tpl)) {
  for (const [lg, v] of Object.entries(byLang)) check("뼈대", k, lg, v, tplKo[k] && tplKo[k].ko);
}
for (const [k, byLang] of Object.entries(words)) {
  for (const [lg, v] of Object.entries(byLang)) check("낱말", k, lg, v, k);
}
for (const [k, byLang] of Object.entries(units)) {
  for (const [lg, v] of Object.entries(byLang)) check("단위", k, lg, v, k);
}
for (const [k, byLang] of Object.entries(arrays)) {
  for (const [lg, arr] of Object.entries(byLang)) arr.forEach((v) => check("배열", k, lg, v, byLang.ko && byLang.ko.join("")));
}

if (bad) {
  console.error(`\n의심 항목 ${bad}건 — 확인이 필요하다`);
  process.exit(1);
}
console.log("글자 체계 검사 통과 — 엉뚱한 언어가 섞인 곳 없음");
