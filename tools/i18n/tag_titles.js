/**
 * 팩의 트랙·유닛·레슨 **제목**에 번역 키(tk)와 인자(ta)를 붙인다.
 *
 *   node tools/i18n/tag_titles.js
 *
 * - 한국어 제목 문자열은 **한 글자도 안 바꾼다** — tk/ta 필드만 얹는다.
 * - 뼈대(SKELETONS)는 templates.json 에 합쳐 넣고, 번역은 tpl/02_titles.js 에 있다.
 * - 자기 검증: 뼈대에 인자를 도로 끼우면 원래 한국어 제목과 정확히 같아야 한다.
 * - 패턴에 안 걸리는 제목(독해 지문 이름 등)은 그대로 둔다 — 그 레슨들은
 *   비한국어 폰에서 문제 자체가 걸러지므로 보이지 않는다.
 *
 * 콘텐츠를 재생성(gen.js)하면 tk 가 사라지므로 **이 스크립트를 다시 돌릴 것.**
 */
const fs = require("fs");
const path = require("path");

const PACKS = path.join(__dirname, "..", "..", "app", "src", "main", "assets", "packs");
const TPL_JSON = path.join(__dirname, "templates.json");

// ---------- 뼈대 원문 (ko) ----------
const SKELETONS = {
  t_tr_basic: "기초 차근차근", t_tr_basic_s: "초등부터 고급까지 10단계",
  t_tr_daily: "일상·여행 영어", t_tr_daily_s: "혼자 해외여행 가는 그날까지",
  t_tr_elem: "초등영어 놀이터", t_tr_elem_s: "알파벳부터 놀면서 배우기",
  t_tr_grammar: "문법 집중", t_tr_grammar_s: "be동사부터 도치·가정법까지",
  t_tr_listen: "듣기 집중", t_tr_listen_s: "단어→문장→대화 귀 트기",
  t_tr_reading: "독해 집중", t_tr_reading_s: "짧은 글→실용문→학술 지문",
  t_tr_speak: "말하기 집중", t_tr_speak_s: "입 트기·실전 회화 발음 훈련",
  t_tr_toefl: "토플 (TOEFL)", t_tr_toefl_s: "학술 독해·리스닝",
  t_tr_toeic: "토익 (TOEIC)", t_tr_toeic_s: "파트별 유형 정복",
  t_tr_write: "쓰기 집중", t_tr_write_s: "철자→어순→영작",

  t_word: "%1$s",
  t_stage: "%1$s단계 %2$s",
  t_stage_n: "%1$s단계 %2$s %3$s",
  t_lesson: "레슨 %1$s",
  t_expr: "%1$s · 표현",
  t_talk2: "%1$s · 말하기",
  t_num: "%1$s %2$s",

  t_u_greet: "인사와 소개", t_u_rest: "식당에서", t_u_shop: "쇼핑", t_u_way: "길 찾기",
  t_u_air: "공항과 비행기", t_u_hotel: "호텔에서", t_u_trans: "교통 이용",
  t_u_emerg: "긴급 상황", t_u_small: "스몰토크", t_u_shop2: "실전 문장 잡화점 %1$s",

  t_g_gram: "%1$s 문법",
  t_g_listen: "귀 트기 %1$s %2$s",
  t_g_read: "%1$s 읽기 %2$s",
  t_g_speak: "입 트기 %1$s %2$s",
  t_g_write: "철자 연습 %1$s %2$s",

  t_s_gramtoeic: "실전 문법 (토익형) %1$s",
  t_s_dict: "문장 받아쓰기 %1$s",
  t_s_dialog: "대화 듣기 훈련 %1$s",
  t_s_pract: "실용문 읽기 %1$s",
  t_s_acad: "학술 지문 읽기 %1$s",
  t_s_conv: "실전 회화 말하기 %1$s",
  t_s_travel: "여행 표현 말하기 %1$s",
  t_s_build: "문장 조립 %1$s",
  t_s_compose: "영작 훈련 %1$s",
  t_s_acread: "학술 독해 %1$s",
  t_s_lecture: "강의 듣기 %1$s",
  t_s_acvocab: "학술 어휘 연구소 %1$s",
  t_s_p5: "Part %1$s 빈칸 채우기 %2$s",
  t_s_p7: "Part %1$s 독해 %2$s",
  t_s_lc: "LC 짧은 대화 %1$s",
  t_s_bizvocab: "비즈니스 어휘 특훈 %1$s",
  t_s_shortdialog: "짧은 대화 듣기",
};

// words_i18n.js 에 등록된 낱말만 인자로 쓴다 (없는 낱말이면 태깅을 포기 — 한국어 유지)
const WORDS = new Set(Object.keys(require("./words_i18n.js")));

const BAND = "(초등 \\d+~\\d+학년|중학 \\d+학년|고등 \\d+학년|고등 \\d+~\\d+학년|성인·비즈니스|고급·학술)";

// [regex, key, 인자 뽑기] — 위에서부터 첫 매치를 쓴다
const RULES = [
  // 고정 유닛 이름 (일상·여행)
  [/^인사와 소개$/, "t_u_greet", () => []],
  [/^식당에서$/, "t_u_rest", () => []],
  [/^쇼핑$/, "t_u_shop", () => []],
  [/^길 찾기$/, "t_u_way", () => []],
  [/^공항과 비행기$/, "t_u_air", () => []],
  [/^호텔에서$/, "t_u_hotel", () => []],
  [/^교통 이용$/, "t_u_trans", () => []],
  [/^긴급 상황$/, "t_u_emerg", () => []],
  [/^스몰토크$/, "t_u_small", () => []],
  [/^실전 문장 잡화점 (\d+)$/, "t_u_shop2", (m) => [m[1]]],
  [/^짧은 대화 듣기$/, "t_s_shortdialog", () => []],

  // 단독 패턴 (학년 띠 규칙보다 먼저!)
  [/^실전 문법 \(토익형\) (\d+)$/, "t_s_gramtoeic", (m) => [m[1]]],
  [/^문장 받아쓰기 (\d+)$/, "t_s_dict", (m) => [m[1]]],
  [/^대화 듣기 훈련 (\d+)$/, "t_s_dialog", (m) => [m[1]]],
  [/^실용문 읽기 (\d+)$/, "t_s_pract", (m) => [m[1]]],
  [/^학술 지문 읽기 (\d+)$/, "t_s_acad", (m) => [m[1]]],
  [/^실전 회화 말하기 (\d+)$/, "t_s_conv", (m) => [m[1]]],
  [/^여행 표현 말하기 (\d+)$/, "t_s_travel", (m) => [m[1]]],
  [/^문장 조립 (\d+)$/, "t_s_build", (m) => [m[1]]],
  [/^영작 훈련 (\d+)$/, "t_s_compose", (m) => [m[1]]],
  [/^학술 독해 (\d+)$/, "t_s_acread", (m) => [m[1]]],
  [/^강의 듣기 (\d+)$/, "t_s_lecture", (m) => [m[1]]],
  [/^학술 어휘 연구소 (\d+)$/, "t_s_acvocab", (m) => [m[1]]],
  [/^Part (\d+) 빈칸 채우기 (\d+)$/, "t_s_p5", (m) => [m[1], m[2]]],
  [/^Part (\d+) 독해 (\d+)$/, "t_s_p7", (m) => [m[1], m[2]]],
  [/^LC 짧은 대화 (\d+)$/, "t_s_lc", (m) => [m[1]]],
  [/^비즈니스 어휘 특훈 (\d+)$/, "t_s_bizvocab", (m) => [m[1]]],

  // 학년 띠 유닛
  [new RegExp("^" + BAND + " 문법$"), "t_g_gram", (m) => [m[1]]],
  [new RegExp("^귀 트기 " + BAND + " (\\d+)$"), "t_g_listen", (m) => [m[1], m[2]]],
  [new RegExp("^" + BAND + " 읽기 (\\d+)$"), "t_g_read", (m) => [m[1], m[2]]],
  [new RegExp("^입 트기 " + BAND + " (\\d+)$"), "t_g_speak", (m) => [m[1], m[2]]],
  [new RegExp("^철자 연습 " + BAND + " (\\d+)$"), "t_g_write", (m) => [m[1], m[2]]],

  // 기초 트랙 "N단계 …( M)"
  [/^(\d+)단계 (.+) (\d+)$/, "t_stage_n", (m) => (WORDS.has(m[2]) ? [m[1], m[2], m[3]] : null)],
  [/^(\d+)단계 (.+)$/, "t_stage", (m) => (WORDS.has(m[2]) ? [m[1], m[2]] : null)],

  // 레슨 제목
  [/^레슨 (\d+)$/, "t_lesson", (m) => [m[1]]],
  [/^(.+) · 표현$/, "t_expr", (m) => (WORDS.has(m[1]) ? [m[1]] : null)],
  [/^(.+) · 말하기$/, "t_talk2", (m) => (WORDS.has(m[1]) ? [m[1]] : null)],
  [/^(.+) (\d+)$/, "t_num", (m) => (WORDS.has(m[1]) ? [m[1], m[2]] : null)],
  [/^(.+)$/, "t_word", (m) => (WORDS.has(m[1]) ? [m[1]] : null)],
];

const TRACK_KEYS = {
  "기초 차근차근": ["t_tr_basic", "t_tr_basic_s"],
  "일상·여행 영어": ["t_tr_daily", "t_tr_daily_s"],
  "초등영어 놀이터": ["t_tr_elem", "t_tr_elem_s"],
  "문법 집중": ["t_tr_grammar", "t_tr_grammar_s"],
  "듣기 집중": ["t_tr_listen", "t_tr_listen_s"],
  "독해 집중": ["t_tr_reading", "t_tr_reading_s"],
  "말하기 집중": ["t_tr_speak", "t_tr_speak_s"],
  "토플 (TOEFL)": ["t_tr_toefl", "t_tr_toefl_s"],
  "토익 (TOEIC)": ["t_tr_toeic", "t_tr_toeic_s"],
  "쓰기 집중": ["t_tr_write", "t_tr_write_s"],
};

/** 뼈대에 인자를 도로 끼워 원문과 같은지 검사한다 (%1$s 채우기) */
function rebuild(key, args) {
  return SKELETONS[key].replace(/%(\d+)\$s/g, (_, n) => args[Number(n) - 1]);
}

function tag(obj, title) {
  for (const [re, key, extract] of RULES) {
    const m = title.match(re);
    if (!m) continue;
    const args = extract(m);
    if (args == null) continue;
    if (rebuild(key, args) !== title) {
      throw new Error(`재조립 불일치: "${title}" → ${key} [${args}]`);
    }
    obj.tk = key;
    if (args.length) obj.ta = args; else delete obj.ta;
    return true;
  }
  return false;
}

// ---------- templates.json 에 뼈대 등록 (기존 키는 그대로 두고 합친다) ----------
const tpl = JSON.parse(fs.readFileSync(TPL_JSON, "utf8"));
let added = 0;
for (const [key, ko] of Object.entries(SKELETONS)) {
  const n = (ko.match(/%\d+\$s/g) || []).length;
  if (!tpl[key]) added++;
  tpl[key] = { ko, args: n, n: tpl[key] ? tpl[key].n : 0 };
}
fs.writeFileSync(TPL_JSON, JSON.stringify(tpl, null, 1), "utf8");

// ---------- 팩 태깅 ----------
let ok = 0, skip = 0;
const skipped = new Map();
for (const f of fs.readdirSync(PACKS)) {
  if (f === "index.json") continue;
  const p = JSON.parse(fs.readFileSync(path.join(PACKS, f), "utf8"));

  if (p.title && TRACK_KEYS[p.title]) {
    p.tk = TRACK_KEYS[p.title][0];
    delete p.ta;
    ok++;
    if (p.subtitle) { p.stk = TRACK_KEYS[p.title][1]; ok++; }
  } else if (p.title) {
    skip++; skipped.set(p.title, (skipped.get(p.title) || 0) + 1);
  }

  for (const u of p.units || []) {
    if (tag(u, u.title)) ok++;
    else { skip++; skipped.set(u.title, (skipped.get(u.title) || 0) + 1); }
    for (const l of u.lessons || []) {
      if (tag(l, l.title)) ok++;
      else { skip++; skipped.set(l.title, (skipped.get(l.title) || 0) + 1); }
    }
  }
  fs.writeFileSync(path.join(PACKS, f), JSON.stringify(p), "utf8");
}
console.log(`뼈대 ${Object.keys(SKELETONS).length}종(신규 ${added}) · 태깅 ${ok}건 · 미태깅 ${skip}건`);
const un = [...skipped.entries()].sort((a, b) => b[1] - a[1]);
if (un.length) {
  console.log("미태깅 제목 (독해 지문 등 — 비한국어 폰에선 해당 레슨이 걸러짐):");
  for (const [t, n] of un.slice(0, 15)) console.log(`  ${n}× ${t}`);
  if (un.length > 15) console.log(`  … 외 ${un.length - 15}종`);
}
