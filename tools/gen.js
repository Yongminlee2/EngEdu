#!/usr/bin/env node
/**
 * 삐약영어 문제팩 생성기.
 * content/ 원천 데이터 → app/src/main/assets/packs/*.json
 * 실행: node tools/gen.js   (프로젝트 루트에서)
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const CONTENT = path.join(ROOT, "content");
const OUT = path.join(ROOT, "app", "src", "main", "assets", "packs");
const DRAWABLE = path.join(ROOT, "app", "src", "main", "res", "drawable-nodpi");

/**
 * 그림이 있는 영어 단어 목록.
 *
 * 뜻을 **한국어 낱말**로 물으면 그 문제는 한국어 화자 전용이 된다.
 * 그림이 있는 단어는 그림으로 물어서 어느 나라 아이도 풀 수 있게 만든다.
 */
const HAS_ART = new Set(
  fs.readdirSync(DRAWABLE)
    .filter((f) => f.startsWith("word_") && f.endsWith(".webp"))
    .map((f) => f.slice(5, -5))
);
const artOf = (w) => {
  const k = String(w).trim().toLowerCase().replace(/[^a-z ]/g, "").replace(/ /g, "_");
  return HAS_ART.has(k) ? "word_" + k : null;
};

// ---------- 시드 난수 (재현 가능) ----------
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rng = mulberry32(20260726);
const ri = (n) => Math.floor(rng() * n);
function shuffled(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = ri(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
/**
 * 낱말 **객체**로 오답을 뽑는다 (뜻과 그림을 함께 알아야 하므로).
 * key(x) 가 겹치지 않는 것만 고른다.
 */
function pickDistinctBy(pool, n, exclude, key) {
  const out = [];
  const seen = new Set([key(exclude)]);
  for (const c of shuffled(pool)) {
    if (out.length >= n) break;
    const k = key(c);
    if (seen.has(k)) continue;
    seen.add(k);
    out.push(c);
  }
  return out;
}

/**
 * 한국어 뜻 → 그림 이름. 보기가 한국어 뜻으로 섞인 뒤에도 짝을 찾을 수 있게,
 * 그 레슨의 낱말 목록으로 역색인을 만들어 돌려준다.
 */
function koArtOf(words) {
  const map = new Map();
  for (const w of words) {
    const a = artOf(w.word);
    if (a && !map.has(w.ko)) map.set(w.ko, a);
  }
  return (ko) => map.get(ko) || null;
}

function pickDistinct(pool, n, exclude) {
  const out = [];
  const cand = shuffled(pool);
  for (const c of cand) {
    if (out.length >= n) break;
    if (exclude.includes(c) || out.includes(c)) continue;
    out.push(c);
  }
  return out;
}

// ---------- ID ----------
const counters = {};
function qid(prefix) {
  counters[prefix] = (counters[prefix] || 0) + 1;
  return prefix + String(counters[prefix]).padStart(5, "0");
}

// ---------- 로더 ----------
function readTsv(file) {
  const p = path.join(CONTENT, file);
  if (!fs.existsSync(p)) return [];
  return fs.readFileSync(p, "utf8").split(/\r?\n/)
    .map((l) => l.trim()).filter((l) => l && !l.startsWith("#"))
    .map((l) => l.split("\t").map((c) => c.trim()));
}
function readJson(file) {
  const p = path.join(CONTENT, file);
  if (!fs.existsSync(p)) return null;
  return JSON.parse(fs.readFileSync(p, "utf8"));
}
function readJsonl(file) {
  const p = path.join(CONTENT, file);
  if (!fs.existsSync(p)) return [];
  return fs.readFileSync(p, "utf8").split(/\r?\n/)
    .map((l) => l.trim()).filter((l) => l && !l.startsWith("#"))
    .map((l) => JSON.parse(l));
}

// ---------- 검증 ----------
let total = 0;
function validate(q) {
  const fail = (m) => { throw new Error(`검증 실패 [${q.id}] ${m}: ${JSON.stringify(q).slice(0, 200)}`); };
  if (["mcq", "reading", "listen_mcq", "listen_dialog"].includes(q.type)) {
    if (!q.choices || q.choices.length !== 4) fail("선택지 4개 아님");
    if (new Set(q.choices).size !== 4) fail("선택지 중복");
    if (q.answer < 0 || q.answer > 3) fail("정답 인덱스");
  }
  if (q.type === "order") {
    const toks = q.en.split(" ").filter(Boolean);
    if (toks.length < 2 || toks.length > 12) fail("타일 수 " + toks.length);
  }
  if (q.type === "match") {
    if (q.pairs.length !== 5) fail("5쌍 아님");
    if (new Set(q.pairs.map((p) => p[0])).size !== 5) fail("왼쪽 중복");
    if (new Set(q.pairs.map((p) => p[1])).size !== 5) fail("오른쪽 중복");
  }
  total++;
  return q;
}

// ---------- MCQ 헬퍼 ----------
/** skill 태그를 붙여서 돌려준다 (실력 대시보드 집계용) */
function tag(q, skill) { if (skill) q.skill = skill; return q; }

function mcq(prefix, prompt, correct, distractors, explain, passage, skill, art) {
  const choices = shuffled([correct, ...distractors]);
  const q = {
    id: qid(prefix), type: passage ? "reading" : "mcq", prompt,
    choices, answer: choices.indexOf(correct),
  };
  // art 가 오면 보기를 그림으로 보여 준다 (보기 순서를 섞은 뒤에 맞춰 붙인다).
  // 하나라도 그림이 없으면 통째로 포기한다 — 그림·글자가 섞인 보기는 읽기 어렵다.
  if (art) {
    const arts = choices.map(art);
    if (arts.every(Boolean)) q.choiceArt = arts;
  }
  if (explain) q.explain = explain;
  if (passage) q.passage = passage;
  if (skill) q.skill = skill;
  return validate(q);
}
function listenMcq(prefix, tts, prompt, correct, distractors, explain, art) {
  const choices = shuffled([correct, ...distractors]);
  const q = { id: qid(prefix), type: "listen_mcq", tts, prompt, choices, answer: choices.indexOf(correct) };
  if (explain) q.explain = explain;
    // 보기를 그림으로 (하나라도 그림이 없으면 통째로 포기 — 섞이면 읽기 어렵다)
  if (art) {
    const arts = choices.map(art);
    if (arts.every(Boolean)) q.choiceArt = arts;
  }
  return validate(q);
}

// 어순 문제 보조 타일 풀
const EXTRA_TILES = ["the", "a", "is", "are", "to", "of", "in", "on", "at", "and", "do", "does", "was", "not", "for", "it", "my", "very"];
function orderQ(prefix, ko, en, explain) {
  const toks = en.split(" ").filter(Boolean);
  const extras = pickDistinct(EXTRA_TILES, 2, toks.map((t) => t.toLowerCase()));
  const q = { id: qid(prefix), type: "order", ko, en, extras };
  if (explain) q.explain = explain;
  return validate(q);
}
function dictationQ(prefix, tts, answer, hintKo, explain) {
  const q = { id: qid(prefix), type: "dictation", tts, answer };
  if (hintKo) q.hintKo = hintKo;
  if (explain) q.explain = explain;
  return validate(q);
}
function speakQ(prefix, en, ko) {
  return validate({ id: qid(prefix), type: "speak", en, ko });
}
function translateQ(prefix, ko, answer, alts, explain) {
  const q = { id: qid(prefix), type: "type_translate", ko, answer };
  if (alts && alts.length) q.alts = alts;
  if (explain) q.explain = explain;
  return validate(q);
}
function matchQ(prefix, pairs) {
  return validate({ id: qid(prefix), type: "match", pairs });
}

// ---------- 레슨/유닛 패킹 ----------
function chunk(arr, n) {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}
let lessonSeq = 0;
function packLessons(questions, per, titleFn) {
  return chunk(questions, per)
    .filter((qs) => qs.length >= Math.min(4, per))
    .map((qs, i) => ({ id: "ls" + (++lessonSeq), title: titleFn ? titleFn(i) : `레슨 ${i + 1}`, questions: qs }));
}
function packUnits(lessons, perUnit, level, titleFn, emojis) {
  return chunk(lessons, perUnit).map((ls, i) => ({
    id: "un" + level + "_" + i + "_" + (lessonSeq++),
    title: titleFn(i),
    emoji: emojis[i % emojis.length],
    level,
    lessons: ls,
  }));
}

// ================= 어휘 로드 =================
// vocab_L{1..10}.tsv: word, pos, ko, example_en, example_ko
const vocab = {};
for (let L = 1; L <= 10; L++) {
  vocab[L] = readTsv(`vocab_L${L}.tsv`).map((c) => ({
    word: c[0], pos: c[1] || "", ko: c[2], exEn: c[3] || "", exKo: c[4] || "",
  })).filter((w) => w.word && w.ko);
}

// 단어가 예문에 포함되는지 (활용형 허용: 앞 4글자 이상 일치)
function blankOut(word, sentence) {
  const re = new RegExp(`\\b${word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "i");
  if (re.test(sentence)) return sentence.replace(re, "___");
  return null;
}

// ================= BASIC =================
function genBasicUnits() {
  const grammar = readJsonl("grammar.jsonl");
  const sentences = readTsv("sentences.tsv").map((c) => ({
    level: +c[0], track: c[1], en: c[2], ko: c[3],
  }));

  const VOCAB_EMOJIS = ["🐣", "🌸", "🍎", "🌈", "🎈", "🧸", "🍀", "🎨", "🚌", "🏠"];

  // 유닛 이름이 내용(주제)을 말하도록 — 전부 "단어마을"이던 문제 수정.
  // 유닛에 어떤 단어가 들어갔는지 보고 가장 많은 주제로 이름 붙인다.
  const THEMES = [
    ["동물", "🐶", "dog cat bird fish rabbit bear lion tiger elephant monkey horse cow pig duck chicken frog snake mouse sheep fox wolf penguin squirrel zoo animal panda giraffe deer whale dolphin shark ant bee butterfly spider turtle hen goat crab octopus puppy kitten"],
    ["음식", "🍎", "apple banana milk bread rice egg water juice candy cookie pizza cake orange grape strawberry peach watermelon food fruit vegetable meat soup tea sugar salt cheese butter jam noodle snack lunch dinner breakfast eat drink hungry thirsty delicious cook potato tomato onion carrot corn bean honey chocolate hamburger sandwich"],
    ["가족과 사람", "👨‍👩‍👧", "mom dad mother father sister brother baby family grandmother grandfather grandma grandpa uncle aunt friend people man woman boy girl child cousin neighbor person king queen prince princess"],
    ["몸과 건강", "💪", "head eye nose mouth ear hand foot arm leg hair face tooth teeth finger body knee shoulder neck back sick doctor hospital medicine healthy hurt strong weak tired"],
    ["학교", "🏫", "school teacher student book pencil eraser desk chair class classroom study read write learn lesson test homework crayon scissors glue paper notebook library dictionary question answer word letter"],
    ["우리 집", "🏠", "house home room door window bed sofa kitchen bathroom table lamp wall roof garden clean wash bath soap towel mirror clock phone computer television key box cup plate spoon knife"],
    ["옷과 물건", "👕", "shirt pants shoes socks hat dress coat skirt button pocket wear glasses umbrella watch ring bag wallet"],
    ["색깔과 모양", "🎨", "red blue yellow green black white pink purple brown color circle square triangle shape line round"],
    ["자연과 날씨", "🌳", "sun moon star sky rain snow wind cloud tree flower grass mountain river sea beach stone leaf weather spring summer fall autumn winter hot cold warm cool rainbow lake forest island world earth fire ice light air rock sand"],
    ["마을과 탈것", "🚌", "car bus train airplane plane bike bicycle boat ship taxi road park store market shop police town city bridge street subway station travel trip map ticket airport farm church museum bank restaurant"],
    ["놀이와 운동", "⚽", "play game ball soccer baseball basketball swim run jump dance sing song music toy doll balloon party birthday present gift fun sport tennis badminton ski skate camp picnic piano guitar drum"],
    ["시간과 하루", "⏰", "time day week month year today tomorrow yesterday morning afternoon evening night hour minute early late calendar season date weekend"],
    ["마음과 행동", "😊", "happy sad angry love like smile cry laugh good bad big small tall short fast slow open close go come see look listen speak talk walk sit stand sleep wake help want give take make think know feel hope brave kind shy scared surprised worry thank sorry please welcome"],
  ].map(([name, emoji, ws]) => [name, emoji, new Set(ws.split(" "))]);

  function retitleVocabUnits(vunits, levelWords, L) {
    if (!vunits.length) return;
    const per = Math.ceil(levelWords.length / vunits.length);
    const seen = new Map();
    vunits.forEach((u, i) => {
      const slice = levelWords.slice(i * per, (i + 1) * per);
      const cnt = new Map();
      for (const w of slice) {
        const t = THEMES.findIndex(([, , set]) => set.has(String(w.word).toLowerCase()));
        if (t >= 0) cnt.set(t, (cnt.get(t) || 0) + 1);
      }
      let best = -1, bestN = 0;
      for (const [t, n] of cnt) if (n > bestN) { best = t; bestN = n; }
      // 주제가 안 잡히는 고급 어휘 유닛은 이름이라도 다양하게 (전부 같은 이름 방지)
      const FALLBACK = [
        ["낱말 탐험", "🧭"], ["단어 여행", "✈️"], ["어휘 산책", "🚶"], ["낱말 캠프", "🏕️"],
        ["단어 보물찾기", "💎"], ["어휘 정원", "🌷"], ["낱말 등대", "🗼"], ["단어 열기구", "🎈"],
      ];
      let [name, emoji] = FALLBACK[i % FALLBACK.length];
      if (best >= 0 && bestN >= 2) { name = THEMES[best][0] + " 마을"; emoji = THEMES[best][1]; }
      const key = L + "|" + name;
      const n = (seen.get(key) || 0) + 1;
      seen.set(key, n);
      u.title = L + "단계 " + name + (n > 1 ? " " + n : "");
      u.emoji = emoji;
    });
  }
  const units = [];

  for (let L = 1; L <= 10; L++) {
    const words = vocab[L];
    if (!words.length) continue;
    const koPool = words.map((w) => w.ko);
    const enPool = words.map((w) => w.word);
    // 오답 선택지 해설용 역방향 사전
    const koToWord = {}; const enToKo = {};
    for (const w of words) {
      if (!koToWord[w.ko]) koToWord[w.ko] = w.word;
      if (!enToKo[w.word]) enToKo[w.word] = w.ko;
    }
    const glossK = (kos) => kos.map((k) => `'${k}'는 ${koToWord[k] || "?"}`).join(" · ");
    const glossE = (ens) => ens.map((e) => `${e}는 '${enToKo[e] || "?"}'`).join(" · ");

// ---------- 미니 상황 랩핑 ----------
// "단어만 덜렁 있어 심심하다"는 피드백. 문제마다 작은 장면을 입힌다.
// 시드 난수 대신 단어 해시로 골라 문제 ID 순서(진행도 호환)를 흔들지 않는다.
function scenePick(key, arr) {
  let h = 0;
  for (const c of String(key)) h = (h * 31 + c.charCodeAt(0)) | 0;
  return arr[Math.abs(h) % arr.length];
}
const SCENE_MEAN = [
  (w) => `"${w}" 의 뜻은?`,
  (w) => `삐약이가 "${w}!" 하고 외쳤어요. 무슨 뜻일까요?`,
  (w) => `칠판에 "${w}" 라고 적혀 있어요. 뜻을 골라 보세요!`,
  (w) => `토끼가 물었어요. "${w} 가 무슨 뜻이야?"`,
  (w) => `그림책에서 "${w}" 를 봤어요. 무슨 뜻일까요?`,
  (w) => `오늘의 단어는 "${w}"! 뜻을 맞혀 볼까요?`,
];
/**
 * 그림 보기 문제의 문제문.
 *
 * 따옴표 안에 들어가는 것은 **영어 단어뿐**이라, 이 문장만 번역하면
 * 어느 언어에서도 그대로 쓸 수 있다 (뜻을 한국어로 적지 않는다).
 */
/** 그림을 보여 주고 영어를 묻는다 — 문장 안에 한국어 낱말이 없다 */
const PROMPT_WHAT_EN = "이 그림을 영어로 뭐라고 할까요?";
/** 듣고 그림을 고른다 */
const PROMPT_HEARD_PIC = "들린 단어의 그림은?";
const SCENE_PICK_ART = [
  (w) => `"${w}" 는 어떤 그림일까요?`,
  (w) => `"${w}" 를 그림에서 찾아 보세요!`,
  (w) => `삐약이가 "${w}" 를 찾고 있어요. 어떤 그림일까요?`,
  (w) => `"${w}" 에 어울리는 그림을 골라 보세요.`,
];
const SCENE_TOEN = [
  (k) => `"${k}" 를 영어로?`,
  (k) => `삐약이에게 "${k}" 를 영어로 알려 주세요!`,
  (k) => `펭귄이 궁금해해요. "${k}" 는 영어로?`,
  (k) => `영어 시간! "${k}" 를 영어로 골라 보세요.`,
  (k) => `엄마가 물었어요. "${k} 가 영어로 뭐야?"`,
];

    const exLine = (w) => (w.exEn ? `\n예문: ${w.exEn}\n      ${w.exKo}` : "");

    // --- 단어 유닛: 6단어 그룹 → 라운드식 출제 ---
    const stream = [];
    for (const group of chunk(words, 6)) {
      if (group.length < 4) continue;
      // 1R: 뜻 고르기
      for (const w of group) {
        // 보기는 **한국어 뜻 그대로** 두고, 같은 뜻의 그림을 나란히 싣는다.
        // 한국 폰은 예전과 똑같이 글자 보기로 풀고,
        // 다른 언어 폰만 같은 문제를 그림 보기로 푼다 (정답 자리는 같다).
        const others = pickDistinctBy(words, 3, w, (x) => x.ko);
        const d = others.map((x) => x.ko);
        stream.push(mcq("b", scenePick(w.word, SCENE_MEAN)(w.word), w.ko, d,
          `📌 ${w.word} (${w.pos}) = ${w.ko}${exLine(w)}\n\n다른 선택지는 각각: ${glossK(d)} 의 뜻이라 오답이에요.`,
          null, null, koArtOf(words)));
      }
      // 2R: 영어로
      for (const w of group) {
        const d = pickDistinct(enPool, 3, [w.word]);
        // 문제문은 한국어 그대로 두고, 그림만 얹는다.
        // 한국 폰은 "사과 를 영어로?" 로 읽고, 다른 언어 폰은 그림을 보고 푼다.
        const art = artOf(w.word);
        const q2 = mcq("b", scenePick(w.ko, SCENE_TOEN)(w.ko), w.word, d,
          `📌 ${w.ko} = ${w.word} (${w.pos})${exLine(w)}\n\n다른 선택지는 각각: ${glossE(d)} 라는 뜻이라 오답이에요.`);
        if (art) q2.bigArt = art;   // 한국어를 못 읽는 폰은 이 그림이 문제가 된다
        stream.push(q2);
      }
      // 3R: 듣고 고르기
      for (const w of group) {
        // 보기는 한국어 뜻 그대로, 그림을 나란히 싣는다 (한국 폰은 예전 그대로)
        const others3 = pickDistinctBy(words, 3, w, (x) => x.ko);
        const d = others3.map((x) => x.ko);
        stream.push(listenMcq("b", w.word, "들린 단어의 뜻은?", w.ko, d,
          `🔊 들려준 단어: ${w.word} = ${w.ko}${exLine(w)}\n\n다른 선택지는 각각: ${glossK(d)} 의 뜻이에요.`, koArtOf(words)));
      }
      // 4R: 받아쓰기(짧은 단어) / 빈칸(긴 단어)
      for (const w of group) {
        if (w.word.length <= 9 && !w.word.includes(" ")) {
          stream.push(dictationQ("b", w.word, w.word, w.ko,
            `📌 ${w.word} = ${w.ko}. 철자를 소리와 함께 기억하세요: ${w.word.split("").join("-")}${exLine(w)}`));
        } else if (w.exEn) {
          const blanked = blankOut(w.word, w.exEn);
          if (blanked) {
            const d = pickDistinct(enPool, 3, [w.word]);
            stream.push(mcq("b", `${blanked}\n(${w.exKo})`, w.word, d,
              `📌 빈칸에는 ${w.word}(${w.ko})가 들어가요.\n완성 문장: ${w.exEn}\n\n다른 선택지는 각각: ${glossE(d)} 라는 뜻이라 문맥에 맞지 않아요.`));
          }
        }
      }
      // 5R: 짝 맞추기
      const five = group.slice(0, 5);
      if (five.length === 5 && new Set(five.map((w) => w.ko)).size === 5)
        stream.push(matchQ("b", five.map((w) => [w.word, w.ko])));
      // 6R: 예문 활용 (order/받아쓰기/말하기 로테이션)
      group.forEach((w, i) => {
        if (!w.exEn) return;
        const toks = w.exEn.split(" ").filter(Boolean);
        const mode = i % 3;
        if (mode === 0 && toks.length >= 3 && toks.length <= 10)
          stream.push(orderQ("b", w.exKo, w.exEn,
            `📌 핵심 단어: ${w.word} = ${w.ko}\n영어는 [주어+동사+목적어] 순서가 기본이에요.`));
        else if (mode === 1 && w.exEn.length <= 60)
          stream.push(dictationQ("b", w.exEn, w.exEn, w.exKo,
            `📌 핵심 단어: ${w.word} = ${w.ko}`));
        else stream.push(speakQ("b", w.exEn, w.exKo));
      });
    }
    const vocabLessons = packLessons(stream, 12);
    {
      const before = units.length;
      units.push(...packUnits(vocabLessons, 5, L,
        (i) => `${L}단계 단어마을 ${i + 1}`, VOCAB_EMOJIS));
      retitleVocabUnits(units.slice(before), words, L);
    }

    // --- 문법 유닛 ---
    const gs = grammar.filter((g) => g.level === L).map((g) =>
      mcq("b", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, null, "grammar"));
    if (gs.length >= 8) {
      const gl = packLessons(gs, 10);
      units.push(...packUnits(gl, 6, L, (i) => `${L}단계 문법 클리닉${gl.length > 6 ? " " + (i + 1) : ""}`, ["⚙️"]));
    }

    // --- 문장 유닛 ---
    const ss = sentences.filter((s) => s.level === L && s.track === "basic");
    const sq = [];
    ss.forEach((s, i) => {
      const toks = s.en.split(" ").filter(Boolean);
      // 문장마다 2가지 유형
      if (toks.length >= 3 && toks.length <= 10) sq.push(orderQ("b", s.ko, s.en));
      switch (i % 3) {
        case 0: if (s.en.length <= 64) { sq.push(dictationQ("b", s.en, s.en, s.ko)); break; }
        // fallthrough
        case 1: sq.push(speakQ("b", s.en, s.ko)); break;
        case 2: sq.push(translateQ("b", `영어로 써 보세요: ${s.ko}`, s.en)); break;
      }
    });
    if (sq.length >= 8) {
      const sl = packLessons(sq, 12);
      units.push(...packUnits(sl, 5, L, (i) => `${L}단계 문장 공방 ${i + 1}`, ["✏️", "📝"]));
    }
  }
  return units;
}

// ================= DAILY =================
function genDailyUnits() {
  const data = readJson("dialogues.json") || { units: [] };
  const sentences = readTsv("sentences.tsv").map((c) => ({
    level: +c[0], track: c[1], en: c[2], ko: c[3],
  })).filter((s) => s.track === "daily");

  const units = [];
  let ulevel = 0;

  for (const u of data.units) {
    ulevel++;
    const lessons = [];
    for (const scene of u.scenes) {
      const lines = scene.lines; // [spk, en, ko]
      const koPool = lines.map((l) => l[2]);

      // 레슨 A: 표현 익히기
      const qa = [];
      for (const [, en, ko] of lines.slice(0, 5))
        qa.push(listenMcq("d", en, "들린 문장의 뜻은?", ko,
          pickDistinct(koPool.length >= 4 ? koPool : koPool.concat(GENERIC_KO), 3, [ko]), `${en}\n= ${ko}`));
      for (const [, en, ko] of lines) {
        const toks = en.split(" ").filter(Boolean);
        if (toks.length >= 3 && toks.length <= 10 && qa.length < 10) qa.push(orderQ("d", ko, en));
      }
      for (const [, en, ko] of lines.slice(0, 2))
        if (en.length <= 55) qa.push(dictationQ("d", en, en, ko));
      if (qa.length >= 4) lessons.push({ id: "ls" + (++lessonSeq), title: `${scene.title} · 표현`, questions: qa.slice(0, 12) });

      // 레슨 B: 듣기·말하기
      const qb = [];
      const dlgLines = lines.map((l) => [l[0], l[1]]);
      for (const g of scene.qs || [])
        qb.push(validate({
          id: qid("d"), type: "listen_dialog", lines: dlgLines, prompt: g.p,
          choices: shuffled([g.c[g.a], ...g.c.filter((_, i) => i !== g.a)]),
          answer: 0, explain: g.e,
        }));
      // listen_dialog 의 answer 인덱스 재계산
      for (const q of qb) if (q.type === "listen_dialog") {
        // 위에서 shuffled 후 첫 요소가 정답이 아니므로 다시 계산
      }
      for (const [, en, ko] of lines.slice(0, 6)) qb.push(speakQ("d", en, ko));
      for (const [, en, ko] of lines.slice(0, 2))
        qb.push(translateQ("d", `영어로 말해 보세요(쓰기): ${ko}`, en));
      if (qb.length >= 4) lessons.push({ id: "ls" + (++lessonSeq), title: `${scene.title} · 말하기`, questions: qb.slice(0, 12) });
    }
    if (lessons.length)
      units.push({ id: "und" + ulevel, title: u.title, emoji: u.emoji || "💬", level: ulevel, lessons });
  }

  // 여행·일상 문장 유닛
  const sq = [];
  sentences.forEach((s, i) => {
    const toks = s.en.split(" ").filter(Boolean);
    switch (i % 4) {
      case 0: if (toks.length >= 3 && toks.length <= 10) { sq.push(orderQ("d", s.ko, s.en)); break; }
      case 1: sq.push(speakQ("d", s.en, s.ko)); break;
      case 2: if (s.en.length <= 60) { sq.push(dictationQ("d", s.en, s.en, s.ko)); break; }
      case 3: sq.push(translateQ("d", `영어로 써 보세요: ${s.ko}`, s.en)); break;
    }
    // 추가 변형: 절반은 speak 도
    if (i % 2 === 0) sq.push(speakQ("d", s.en, s.ko));
  });
  const sl = packLessons(sq, 12);
  packUnits(sl, 5, ++ulevel, (i) => `실전 문장 잡화점 ${i + 1}`, ["🧳", "🗺️"]).forEach((u) => {
    u.level = ulevel; units.push(u); ulevel++;
  });
  return units;
}
const GENERIC_KO = ["안녕하세요.", "감사합니다.", "죄송합니다.", "좋은 하루 되세요."];

// ================= TOEIC =================
function genToeicUnits() {
  const data = readJson("toeic.json") || { p5: [], p7: [], lc: [] };
  const units = [];
  let lv = 0;

  // Part5
  const p5 = data.p5.map((g) => mcq("t", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, null, "grammar"));
  if (p5.length) {
    const ls = packLessons(p5, 10);
    units.push(...packUnits(ls, 5, ++lv, (i) => `Part 5 빈칸 채우기 ${i + 1}`, ["📄"]));
    lv += Math.max(0, Math.ceil(ls.length / 5) - 1);
  }

  // Part7 독해: 지문당 문항들 (지문 첨부)
  const p7lessons = [];
  for (const pack of chunk(data.p7, 2)) {
    const qs = [];
    for (const psg of pack)
      for (const g of psg.qs)
        qs.push(mcq("t", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, psg.passage));
    if (qs.length >= 4) p7lessons.push({ id: "ls" + (++lessonSeq), title: pack.map((p) => p.title).join(" · "), questions: qs });
  }
  if (p7lessons.length)
    units.push(...packUnits(p7lessons, 5, ++lv, (i) => `Part 7 독해 ${i + 1}`, ["📰"]));

  // LC
  const lcLessons = [];
  for (const pack of chunk(data.lc, 2)) {
    const qs = [];
    for (const d of pack)
      for (const g of d.qs)
        qs.push(validate({
          id: qid("t"), type: "listen_dialog", lines: d.lines, prompt: g.p,
          choices: g.c, answer: g.a, explain: g.e,
        }));
    if (qs.length >= 4) lcLessons.push({ id: "ls" + (++lessonSeq), title: "짧은 대화 듣기", questions: qs });
  }
  if (lcLessons.length)
    units.push(...packUnits(lcLessons, 5, ++lv, (i) => `LC 짧은 대화 ${i + 1}`, ["🎧"]));

  // 토익 어휘 트레이닝 (L9 어휘의 빈칸·예문 받아쓰기)
  const words = vocab[9] || [];
  const enPool = words.map((w) => w.word);
  const enToKo9 = {}; for (const w of words) if (!enToKo9[w.word]) enToKo9[w.word] = w.ko;
  const tq = [];
  for (const w of words) {
    if (w.exEn) {
      const blanked = blankOut(w.word, w.exEn);
      if (blanked) {
        const d = pickDistinct(enPool, 3, [w.word]);
        tq.push(mcq("t", `${blanked}\n(${w.exKo})`, w.word, d,
          `📌 정답: ${w.word} = ${w.ko}\n완성 문장: ${w.exEn}\n\n다른 선택지는 각각: ${d.map((e) => `${e}는 '${enToKo9[e] || "?"}'`).join(" · ")} 라는 뜻이라 문맥에 맞지 않아요.`));
      }
      if (w.exEn.length <= 60) tq.push(dictationQ("t", w.exEn, w.exEn, w.exKo,
        `📌 핵심 비즈니스 어휘: ${w.word} = ${w.ko}`));
    }
  }
  if (tq.length) {
    const ls = packLessons(tq, 12);
    units.push(...packUnits(ls, 5, ++lv, (i) => `비즈니스 어휘 특훈 ${i + 1}`, ["💼"]));
  }
  return units;
}

// ================= TOEFL =================
function genToeflUnits() {
  const data = readJson("toefl.json") || { reading: [], lectures: [], vocabq: [] };
  const units = [];
  let lv = 0;

  const rdLessons = [];
  for (const psg of data.reading) {
    const qs = psg.qs.map((g) => mcq("f", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, psg.passage));
    if (qs.length >= 2) rdLessons.push({ id: "ls" + (++lessonSeq), title: psg.title, questions: qs });
  }
  if (rdLessons.length)
    units.push(...packUnits(rdLessons, 5, ++lv, (i) => `학술 독해 ${i + 1}`, ["🔬"]));

  const lecLessons = [];
  for (const lec of data.lectures) {
    const qs = lec.qs.map((g) => validate({
      id: qid("f"), type: "listen_dialog", lines: lec.lines, prompt: g.p,
      choices: g.c, answer: g.a, explain: g.e,
    }));
    if (qs.length >= 2) lecLessons.push({ id: "ls" + (++lessonSeq), title: lec.title || "강의 듣기", questions: qs });
  }
  if (lecLessons.length)
    units.push(...packUnits(lecLessons, 5, ++lv, (i) => `강의 듣기 ${i + 1}`, ["🏛️"]));

  // 학술 어휘
  const words = vocab[10] || [];
  const enPool = words.map((w) => w.word);
  const enToKo10 = {}; for (const w of words) if (!enToKo10[w.word]) enToKo10[w.word] = w.ko;
  const fq = (data.vocabq || []).map((g) => mcq("f", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e));
  for (const w of words) {
    if (w.exEn) {
      const blanked = blankOut(w.word, w.exEn);
      if (blanked) {
        const d = pickDistinct(enPool, 3, [w.word]);
        fq.push(mcq("f", `${blanked}\n(${w.exKo})`, w.word, d,
          `📌 정답: ${w.word} = ${w.ko}\n완성 문장: ${w.exEn}\n\n다른 선택지는 각각: ${d.map((e) => `${e}는 '${enToKo10[e] || "?"}'`).join(" · ")} 라는 뜻이라 문맥에 맞지 않아요.`));
      }
      if (w.exEn.length <= 64) fq.push(dictationQ("f", w.exEn, w.exEn, w.exKo,
        `📌 핵심 학술 어휘: ${w.word} = ${w.ko}`));
    }
  }
  if (fq.length) {
    const ls = packLessons(fq, 12);
    units.push(...packUnits(ls, 5, ++lv, (i) => `학술 어휘 연구소 ${i + 1}`, ["🧪"]));
  }
  return units;
}

// ================= 기능별 트랙 (듣기·말하기·쓰기·문법) =================
// 같은 원천 데이터를 "영역별 집중 훈련" 관점으로 다시 엮는다. 문제 ID가 달라서
// 기초·여행 트랙과 진행도가 따로 쌓이고, 실력 대시보드의 영역별 레벨을 올리는 통로가 된다.

const LEVEL_LABEL = {
  1: "초등 1~2학년", 2: "초등 3~4학년", 3: "초등 5~6학년", 4: "중학 1학년", 5: "중학 2학년",
  6: "중학 3학년", 7: "고등 1학년", 8: "고등 2~3학년", 9: "성인·비즈니스", 10: "고급·학술",
};

function allSentences() {
  return readTsv("sentences.tsv").map((c) => ({ level: +c[0], track: c[1], en: c[2], ko: c[3] }));
}
function allDialogueLines() {
  const data = readJson("dialogues.json") || { units: [] };
  const out = [];
  for (const u of data.units)
    for (const s of u.scenes)
      out.push({ title: `${u.title} · ${s.title}`, emoji: u.emoji || "💬", lines: s.lines });
  return out;
}

// --- 🎧 듣기 트랙 ---
function genListeningUnits() {
  const units = [];
  const sentences = allSentences();
  let lv = 0;

  // 1) 레벨별 단어 듣기 + 짧은 받아쓰기
  for (let L = 1; L <= 10; L++) {
    const words = vocab[L] || [];
    if (words.length < 12) continue;
    const koPool = words.map((w) => w.ko);
    const enToKo = {}; for (const w of words) if (!enToKo[w.word]) enToKo[w.word] = w.ko;
    const qs = [];
    for (const w of words) {
      const d = pickDistinct(koPool, 3, [w.ko]);
      qs.push(listenMcq("L", w.word, "들린 단어의 뜻은?", w.ko, d,
        `🔊 ${w.word} = ${w.ko}\n\n다른 선택지: ${d.map((k) => `'${k}'`).join(" · ")}\n귀로 들은 소리와 철자를 함께 떠올려 보세요.`));
      if (w.word.length <= 10 && !w.word.includes(" "))
        qs.push(dictationQ("L", w.word, w.word, w.ko, `📌 ${w.word} = ${w.ko}\n철자: ${w.word.split("").join("-")}`));
    }
    const ls = packLessons(shuffled(qs), 12);
    units.push(...packUnits(ls, 4, ++lv, (i) => `귀 트기 ${LEVEL_LABEL[L]} ${i + 1}`, ["👂", "🎧"]));
  }

  // 2) 문장 받아쓰기 (레벨 순)
  const sq = [];
  for (const s of sentences.slice().sort((a, b) => a.level - b.level)) {
    if (s.en.length <= 70) sq.push(dictationQ("L", s.en, s.en, s.ko, `📝 ${s.ko}\n= ${s.en}`));
  }
  units.push(...packUnits(packLessons(sq, 10), 4, ++lv, (i) => `문장 받아쓰기 ${i + 1}`, ["✏️", "🎧"]));

  // 3) 대화 듣기 (일상·여행 27장면)
  const dq = [];
  for (const sc of allDialogueLines()) {
    const dlg = sc.lines.map((l) => [l[0], l[1]]);
    const koPool = sc.lines.map((l) => l[2]);
    for (const [, en, ko] of sc.lines) {
      const d = pickDistinct(koPool.concat(GENERIC_KO), 3, [ko]);
      if (d.length < 3) continue;
      dq.push(validate({
        id: qid("L"), type: "listen_dialog", lines: dlg,
        prompt: `대화 중 "${en.split(" ").slice(0, 3).join(" ")}..." 문장의 뜻은?`,
        choices: shuffled([ko, ...d]), answer: 0, skill: "listening",
        explain: `🔊 ${en}\n= ${ko}\n\n대화 전체를 다시 들으며 흐름을 확인해 보세요.`,
      }));
      // shuffled 후 정답 인덱스 보정
      const last = dq[dq.length - 1];
      last.answer = last.choices.indexOf(ko);
    }
  }
  units.push(...packUnits(packLessons(dq, 10), 4, ++lv, (i) => `대화 듣기 훈련 ${i + 1}`, ["🗣️", "🎧"]));
  return units;
}

// --- 🎤 말하기 트랙 ---
function genSpeakingUnits() {
  const units = [];
  const sentences = allSentences();
  let lv = 0;

  // 1) 단어·예문 따라 말하기 (레벨별)
  for (let L = 1; L <= 10; L++) {
    const words = (vocab[L] || []).filter((w) => w.exEn);
    if (words.length < 12) continue;
    const qs = [];
    for (const w of words) {
      qs.push(speakQ("S", w.exEn, `${w.exKo}  (핵심어 ${w.word} = ${w.ko})`));
    }
    const ls = packLessons(qs, 8);
    units.push(...packUnits(ls, 4, ++lv, (i) => `입 트기 ${LEVEL_LABEL[L]} ${i + 1}`, ["🗣️", "🎤"]));
  }

  // 2) 실전 회화 따라 말하기 (대화 장면별)
  const dq = [];
  for (const sc of allDialogueLines())
    for (const [, en, ko] of sc.lines) dq.push(speakQ("S", en, ko));
  units.push(...packUnits(packLessons(dq, 8), 4, ++lv, (i) => `실전 회화 말하기 ${i + 1}`, ["✈️", "🎤"]));

  // 3) 여행·일상 표현 말하기
  const tq = sentences.filter((s) => s.track === "daily").map((s) => speakQ("S", s.en, s.ko));
  units.push(...packUnits(packLessons(tq, 8), 4, ++lv, (i) => `여행 표현 말하기 ${i + 1}`, ["🧳", "🎤"]));
  return units;
}

// --- ✍️ 쓰기 트랙 ---
function genWritingUnits() {
  const units = [];
  const sentences = allSentences();
  let lv = 0;

  // 1) 단어 철자 쓰기 (레벨별)
  for (let L = 1; L <= 10; L++) {
    const words = (vocab[L] || []).filter((w) => !w.word.includes(" "));
    if (words.length < 12) continue;
    const qs = words.map((w) =>
      translateQ("W", `"${w.ko}" 를 영어로 쓰세요`, w.word, [],
        `📌 ${w.ko} = ${w.word} (${w.pos})${w.exEn ? `\n예문: ${w.exEn}` : ""}`));
    units.push(...packUnits(packLessons(qs, 10), 4, ++lv,
      (i) => `철자 연습 ${LEVEL_LABEL[L]} ${i + 1}`, ["🔤", "✍️"]));
  }

  // 2) 어순 배열 (문장 조립)
  const oq = [];
  for (const s of sentences.slice().sort((a, b) => a.level - b.level)) {
    const toks = s.en.split(" ").filter(Boolean);
    if (toks.length >= 3 && toks.length <= 11)
      oq.push(orderQ("W", s.ko, s.en, "📌 영어 어순의 기본은 [주어 → 동사 → 목적어] 예요."));
  }
  units.push(...packUnits(packLessons(oq, 10), 4, ++lv, (i) => `문장 조립 ${i + 1}`, ["🧩", "✍️"]));

  // 3) 한→영 영작
  const tq = [];
  for (const s of sentences.slice().sort((a, b) => a.level - b.level))
    tq.push(translateQ("W", `영어로 써 보세요: ${s.ko}`, s.en, [], `📌 모범 답안: ${s.en}`));
  units.push(...packUnits(packLessons(tq, 10), 4, ++lv, (i) => `영작 훈련 ${i + 1}`, ["📝", "✍️"]));
  return units;
}

// --- 📚 독해 트랙 ---
function genReadingUnits() {
  const data = readJson("reading.json") || { passages: [] };
  const toeic = readJson("toeic.json") || { p7: [] };
  const toefl = readJson("toefl.json") || { reading: [] };
  const units = [];
  let lv = 0;

  // 1) 레벨별 짧은 지문 (자체 저작)
  const byLevel = {};
  for (const p of data.passages) (byLevel[p.level] = byLevel[p.level] || []).push(p);
  for (const L of Object.keys(byLevel).map(Number).sort((a, b) => a - b)) {
    const lessons = [];
    for (const p of byLevel[L]) {
      const qs = p.qs.map((g) =>
        mcq("R", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, p.passage, "reading"));
      // 지문의 핵심 문장 받아쓰기 대신, 지문 이해 문제만으로 레슨 구성
      if (qs.length >= 2) lessons.push({ id: "ls" + (++lessonSeq), title: p.title, questions: qs });
    }
    if (lessons.length)
      units.push(...packUnits(lessons, 4, ++lv,
        (i) => `${LEVEL_LABEL[L]} 읽기 ${i + 1}`, ["📚", "📖"]));
  }

  // 2) 실용문 독해 (토익 P7)
  const p7 = [];
  for (const psg of toeic.p7) {
    const qs = psg.qs.map((g) =>
      mcq("R", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, psg.passage, "reading"));
    if (qs.length >= 2) p7.push({ id: "ls" + (++lessonSeq), title: psg.title, questions: qs });
  }
  if (p7.length) units.push(...packUnits(p7, 4, ++lv, (i) => `실용문 읽기 ${i + 1}`, ["📰", "📚"]));

  // 3) 학술 지문 독해 (토플)
  const ac = [];
  for (const psg of toefl.reading) {
    const qs = psg.qs.map((g) =>
      mcq("R", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, psg.passage, "reading"));
    if (qs.length >= 2) ac.push({ id: "ls" + (++lessonSeq), title: psg.title, questions: qs });
  }
  if (ac.length) units.push(...packUnits(ac, 4, ++lv, (i) => `학술 지문 읽기 ${i + 1}`, ["🔬", "📚"]));
  return units;
}

// --- 📖 문법 트랙 ---
function genGrammarUnits() {
  const grammar = readJsonl("grammar.jsonl");
  const toeic = readJson("toeic.json") || { p5: [] };
  const units = [];
  let lv = 0;

  for (let L = 1; L <= 10; L++) {
    const gs = grammar.filter((g) => g.level === L)
      .map((g) => mcq("G", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, null, "grammar"));
    if (gs.length < 8) continue;
    units.push(...packUnits(packLessons(gs, 8), 4, ++lv,
      (i) => `${LEVEL_LABEL[L]} 문법${gs.length > 32 ? " " + (i + 1) : ""}`, ["📖", "⚙️"]));
  }
  // 실전 문법 (토익 Part5 유형)
  const p5 = toeic.p5.map((g) => mcq("G", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e, null, "grammar"));
  if (p5.length >= 8)
    units.push(...packUnits(packLessons(p5, 8), 4, ++lv, (i) => `실전 문법 (토익형) ${i + 1}`, ["💼", "📖"]));
  return units;
}

// ================= 배치고사 =================
function genPlacement() {
  const grammar = readJsonl("grammar.jsonl");
  const questions = [];
  for (let L = 1; L <= 10; L++) {
    const words = shuffled(vocab[L] || []).slice(0, 8);
    const koPool = (vocab[L] || []).map((w) => w.ko);
    for (const w of words) {
      const q = mcq("p", `"${w.word}" 의 뜻은?`, w.ko, pickDistinct(koPool, 3, [w.ko]));
      q.level = L;
      questions.push(q);
    }
    for (const g of grammar.filter((g) => g.level === L).slice(0, 2)) {
      const q = mcq("p", g.p, g.c[g.a], g.c.filter((_, i) => i !== g.a), g.e);
      q.level = L;
      questions.push(q);
    }
  }
  return { questions };
}

// ================= 실행 =================
fs.mkdirSync(OUT, { recursive: true });
const tracks = [
  {
    id: "basic", title: "기초 차근차근", emoji: "🌱", color: "#B7E3C0",
    subtitle: "초등부터 고급까지 10단계", units: genBasicUnits(),
  },
  {
    id: "daily", title: "일상·여행 영어", emoji: "✈️", color: "#AEDCF5",
    subtitle: "혼자 해외여행 가는 그날까지", units: genDailyUnits(),
  },
  {
    id: "toeic", title: "토익 (TOEIC)", emoji: "💼", color: "#F5D9A8",
    subtitle: "파트별 유형 정복", units: genToeicUnits(),
  },
  {
    id: "toefl", title: "토플 (TOEFL)", emoji: "🎓", color: "#D8CBF0",
    subtitle: "학술 독해·리스닝", units: genToeflUnits(),
  },
  {
    id: "listening", title: "듣기 집중", emoji: "🎧", color: "#AEE3F0",
    subtitle: "단어→문장→대화 귀 트기", units: genListeningUnits(),
  },
  {
    id: "speaking", title: "말하기 집중", emoji: "🎤", color: "#F7C6C7",
    subtitle: "입 트기·실전 회화 발음 훈련", units: genSpeakingUnits(),
  },
  {
    id: "writing", title: "쓰기 집중", emoji: "✍️", color: "#CFE8B8",
    subtitle: "철자→어순→영작", units: genWritingUnits(),
  },
  {
    id: "grammar", title: "문법 집중", emoji: "📖", color: "#F3D7B0",
    subtitle: "be동사부터 도치·가정법까지", units: genGrammarUnits(),
  },
  {
    id: "reading", title: "독해 집중", emoji: "📚", color: "#E3D5F5",
    subtitle: "짧은 글→실용문→학술 지문", units: genReadingUnits(),
  },
];

let report = [];
for (const t of tracks) {
  const nQ = t.units.reduce((s, u) => s + u.lessons.reduce((x, l) => x + l.questions.length, 0), 0);
  const nL = t.units.reduce((s, u) => s + u.lessons.length, 0);
  report.push(`${t.id}: 유닛 ${t.units.length} · 레슨 ${nL} · 문제 ${nQ}`);
  fs.writeFileSync(path.join(OUT, `${t.id}.json`), JSON.stringify(t), "utf8");
}
const placement = genPlacement();
fs.writeFileSync(path.join(OUT, "placement.json"), JSON.stringify(placement), "utf8");
report.push(`placement: ${placement.questions.length}문제`);
report.push(`총 문제 수: ${total}`);
console.log(report.join("\n"));
