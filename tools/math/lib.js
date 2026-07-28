// 수학 문제 생성 공용 도구
// 문제는 미리 구워서 팩에 고정한다 — ID가 고정돼야 오답노트·진행도·코인이 작동한다.

// ---------- 시드 난수 (재현 가능) ----------
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rng = mulberry32(20260727);
const ri = (n) => Math.floor(rng() * n);
/** lo 이상 hi 이하 정수 */
const rint = (lo, hi) => lo + ri(hi - lo + 1);
const pick = (arr) => arr[ri(arr.length)];

function shuffled(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = ri(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// ---------- ID ----------
let seq = 0;
function qid() {
  seq++;
  return "M" + String(seq).padStart(6, "0");
}

let lessonSeq = 0;
function lessonId() {
  lessonSeq++;
  return "ml" + lessonSeq;
}

// ---------- 검증 ----------
let total = 0;
const VISUAL_KINDS = new Set([
  "emoji", "emoji_op", "array", "shapes", "clock", "fraction",
  "number_line", "bar_graph", "angle", "compare",
  // 그림을 손으로 조작해서 답하는 종류
  "clock_set", "group", "fraction_paint", "shape_sort",
]);

function validate(q) {
  const fail = (m) => {
    throw new Error(`검증 실패 [${q.id}] ${m}: ${JSON.stringify(q).slice(0, 220)}`);
  };
  if (!q.prompt) fail("prompt 없음");
  if (q.input === "choice") {
    if (!q.choices || q.choices.length !== 4) fail("선택지 4개 아님");
    if (new Set(q.choices).size !== 4) fail("선택지 중복");
    if (q.answerIndex < 0 || q.answerIndex > 3) fail("정답 인덱스");
  } else {
    if (q.answer === undefined || q.answer === "") fail("answer 없음");
  }
  if (q.visual && !VISUAL_KINDS.has(q.visual.kind)) fail("알 수 없는 visual: " + q.visual.kind);
  if (!q.explain) fail("해설 없음");
  total++;
  return q;
}

// ---------- 문제 빌더 ----------
/** 숫자 키패드로 답하는 문제 */
function numQ(prompt, answer, explain, opts = {}) {
  return validate({
    id: qid(), type: "math", prompt,
    input: "number", answer: String(answer),
    ...(opts.alts ? { alts: opts.alts.map(String) } : {}),
    ...(opts.unit ? { unit: opts.unit } : {}),
    ...(opts.visual ? { visual: opts.visual } : {}),
    ...(opts.skill ? { skill: opts.skill } : {}),
    explain,
  });
}

/**
 * 4지선다. 서로 다른 선택지 4개를 못 만들면 null 을 돌려준다
 * (gen 이 다른 난수로 다시 뽑는다) — 중복 선택지가 팩에 들어가는 걸 막는다.
 */
function choiceQ(prompt, correct, distractors, explain, opts = {}) {
  const seen = new Set([String(correct)]);
  const clean = [];
  for (const d of distractors) {
    const s = String(d);
    if (seen.has(s)) continue;
    seen.add(s);
    clean.push(s);
    if (clean.length === 3) break;
  }
  if (clean.length < 3) return null;
  const choices = shuffled([String(correct), ...clean]);
  return validate({
    id: qid(), type: "math", prompt,
    input: "choice", choices, answerIndex: choices.indexOf(String(correct)),
    ...(opts.visual ? { visual: opts.visual } : {}),
    ...(opts.skill ? { skill: opts.skill } : {}),
    explain,
  });
}

/**
 * 그림을 직접 조작해서 답하는 문제.
 * 시계 바늘을 돌리거나 사물을 끌어다 나눠 담으면 앱이 결과를 읽어 채점한다.
 * answer 는 시계면 "H:MM", 나눠 담기면 한 묶음의 개수.
 */
function visualQ(prompt, answer, explain, opts = {}) {
  return validate({
    id: qid(), type: "math", prompt,
    input: "visual", answer: String(answer),
    ...(opts.visual ? { visual: opts.visual } : {}),
    ...(opts.skill ? { skill: opts.skill } : {}),
    explain,
  });
}

/** 식·문자로 답하는 문제 (중·고등) */
function textQ(prompt, answer, explain, opts = {}) {
  return validate({
    id: qid(), type: "math", prompt,
    input: "text", answer: String(answer),
    ...(opts.alts ? { alts: opts.alts.map(String) } : {}),
    ...(opts.visual ? { visual: opts.visual } : {}),
    ...(opts.skill ? { skill: opts.skill } : {}),
    explain,
  });
}

// ---------- 그림 명세 ----------
const V = {
  emoji: (emoji, n) => ({ kind: "emoji", emoji, a: n }),
  emojiOp: (emoji, a, b, op) => ({ kind: "emoji_op", emoji, a, b, op }),
  array: (emoji, rows, cols) => ({ kind: "array", emoji, a: rows, b: cols }),
  shapes: (names) => ({ kind: "shapes", labels: names }),
  clock: (h, m) => ({ kind: "clock", p: h, q: m }),
  fraction: (n, d) => ({ kind: "fraction", p: n, q: d }),
  numberLine: (lo, hi, marks) => ({ kind: "number_line", p: lo, q: hi, values: marks }),
  barGraph: (labels, values) => ({ kind: "bar_graph", labels, values }),
  angle: (deg) => ({ kind: "angle", p: deg }),
  compare: (emojiA, a, emojiB, b) => ({ kind: "compare", emoji: emojiA, a, b, labels: [emojiB] }),
  /** 바늘을 끌어 맞추는 시계 — p·q 는 정답 시·분 */
  clockSet: (h, m) => ({ kind: "clock_set", p: h, q: m }),
  /** 사물을 끌어다 묶음에 나눠 담기 — a 는 전체 개수, b 는 묶음 수 */
  group: (emoji, total, groups) => ({ kind: "group", emoji, a: total, b: groups }),
  /** 조각을 눌러 색칠하기 — p 는 칠해야 할 칸 수, q 는 전체 칸 수 */
  fractionPaint: (n, d) => ({ kind: "fraction_paint", p: n, q: d }),
  /** 도형을 이름 붙은 바구니로 분류하기 — kinds[i] 는 items[i] 가 들어갈 바구니 */
  shapeSort: (items, kinds, labels) => ({ kind: "shape_sort", items, kinds, labels }),
};

/** 모양별 이모지 — 같은 종류라도 색·방향이 달라야 "모양"으로 분류하게 된다 */
const SHAPE_POOL = {
  삼각형: ["🔺", "🔻", "🔼", "🔽"],
  사각형: ["🟥", "🟦", "🟩", "🟨", "🟧", "🟪"],
  원: ["🔴", "🔵", "🟢", "🟡", "🟠", "🟣"],
};

const SHAPE_HINT = {
  삼각형: "뾰족한 곳이 3개",
  사각형: "뾰족한 곳이 4개",
  원: "뾰족한 곳이 없고 동그란",
};

// 아이가 좋아하는 사물 이모지
const FRUITS = ["🍎", "🍓", "🍊", "🍇", "🍌", "🍑", "🍉", "🥝"];
const ANIMALS = ["🐥", "🐶", "🐱", "🐰", "🐸", "🐼", "🐧", "🦊"];
const THINGS = ["⭐", "🎈", "🍪", "🚗", "✏️", "🌸", "🧸", "⚽"];
const ALL_EMOJI = [...FRUITS, ...ANIMALS, ...THINGS];

// ---------- 오답 만들기 ----------
/** 정답 근처의 그럴듯한 오답 3개 (중복·음수 방지) */
function nearWrong(answer, spread = 3, allowNegative = false) {
  const out = new Set();
  let guard = 0;
  while (out.size < 3 && guard++ < 100) {
    const d = rint(1, spread) * (rng() < 0.5 ? -1 : 1);
    const w = answer + d;
    if (w === answer) continue;
    if (!allowNegative && w < 0) continue;
    out.add(w);
  }
  let n = answer + 10;
  while (out.size < 3) out.add(n++);
  return [...out];
}

// ---------- 레슨/유닛 패킹 ----------
function chunk(arr, n) {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

/** 문제 배열 → 레슨 배열 (기본 10문제) */
function packLessons(questions, per, titleFn) {
  return chunk(questions, per || 10)
    .filter((qs) => qs.length >= 4)
    .map((qs, i) => ({
      id: lessonId(),
      title: titleFn ? titleFn(i) : `연습 ${i + 1}`,
      questions: qs,
    }));
}

/** 단원 하나 = 유닛 하나 */
function unit(title, emoji, level, lessons) {
  return { id: "mu" + (++lessonSeq), title, emoji, level, lessons };
}

/** 문제들을 받아 단원(유닛) 하나로 만든다 */
function makeUnit(title, emoji, level, questions, per) {
  const lessons = packLessons(questions, per, (i) => `${title} ${i + 1}`);
  if (!lessons.length) return null;
  return unit(title, emoji, level, lessons);
}

/**
 * 문제를 넉넉히 뽑는 배수. 생성기마다 만들 수 있는 서로 다른 문제의 수가 다른데,
 * gen 이 중복을 버리므로 실제로는 각 생성기의 한계까지만 나온다 — 크게 잡아도 안전하다.
 */
const SCALE = 4;

/** n개를 만들되 중복 문제(같은 prompt+그림)는 버린다 */
function gen(want, fn) {
  const n = Math.round(want * SCALE);
  const out = [];
  const seen = new Set();
  let guard = 0;
  while (out.length < n && guard++ < n * 25) {
    const q = fn();
    if (!q) continue;
    const key = q.prompt + "|" + JSON.stringify(q.visual || "");
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(q);
  }
  return out;
}

module.exports = {
  rng, ri, rint, pick, shuffled,
  numQ, choiceQ, textQ, visualQ, V,
  FRUITS, ANIMALS, THINGS, ALL_EMOJI, SHAPE_POOL, SHAPE_HINT,
  nearWrong, packLessons, makeUnit, gen, chunk, SCALE,
  stats: () => ({ total }),
};
