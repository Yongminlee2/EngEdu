#!/usr/bin/env node
/**
 * 초등영어 코스 생성기 — 알파벳부터 놀이처럼.
 * 그림(이모지) 위주 4지선다와 듣기·말하기로 구성한다.
 * 실행: node tools/gen_elem_english.js
 */
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "app", "src", "main", "assets", "packs");
fs.mkdirSync(OUT, { recursive: true });

// ---------- 난수 ----------
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rng = mulberry32(20260728);
const ri = (n) => Math.floor(rng() * n);
const pick = (a) => a[ri(a.length)];
function shuffled(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) { const j = ri(i + 1); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}

let seq = 0;
const qid = () => "E" + String(++seq).padStart(5, "0");
let lseq = 0;
const lid = () => "el" + ++lseq;

let total = 0;
function validate(q) {
  const fail = (m) => { throw new Error(`검증 실패 [${q.id}] ${m}`); };
  if (q.type === "mcq") {
    if (!q.choices || q.choices.length !== 4) fail("선택지 4개 아님");
    if (new Set(q.choices).size !== 4) fail("선택지 중복");
    if (q.answer < 0 || q.answer > 3) fail("정답 인덱스");
  }
  if (!q.explain) fail("해설 없음");
  total++;
  return q;
}

/** 4지선다. 서로 다른 4개를 못 만들면 null (다시 뽑는다) */
function mcq(prompt, correct, distractors, explain, opts = {}) {
  const seen = new Set([String(correct)]);
  const clean = [];
  for (const d of distractors) {
    const s = String(d);
    if (seen.has(s)) continue;
    seen.add(s); clean.push(s);
    if (clean.length === 3) break;
  }
  if (clean.length < 3) return null;
  const choices = shuffled([String(correct), ...clean]);
  return validate({
    id: qid(), type: "mcq", prompt, choices, answer: choices.indexOf(String(correct)),
    ...(opts.bigEmoji ? { bigEmoji: opts.bigEmoji } : {}),
    ...(opts.skill ? { skill: opts.skill } : {}),
    explain,
  });
}
function listenMcq(tts, prompt, correct, distractors, explain) {
  const seen = new Set([String(correct)]);
  const clean = [];
  for (const d of distractors) {
    const s = String(d);
    if (seen.has(s)) continue;
    seen.add(s); clean.push(s);
    if (clean.length === 3) break;
  }
  if (clean.length < 3) return null;
  const choices = shuffled([String(correct), ...clean]);
  return validate({
    id: qid(), type: "listen_mcq", tts, prompt,
    choices, answer: choices.indexOf(String(correct)), explain,
  });
}
function speakQ(en, ko) {
  return validate({ id: qid(), type: "speak", en, ko, explain: `또박또박 읽어 봐요: ${en}` });
}
function dictationQ(tts, answer, hintKo, explain) {
  return validate({ id: qid(), type: "dictation", tts, answer, hintKo, explain });
}

function gen(n, fn) {
  const out = [];
  const seen = new Set();
  let guard = 0;
  while (out.length < n && guard++ < n * 30) {
    const q = fn();
    if (!q) continue;
    // 듣기 문제는 prompt 가 고정("무엇이 들렸나요?")이라 tts·정답까지 넣어야 구분된다
    const key = [q.prompt, q.tts, q.en, q.answer, q.bigEmoji].filter(Boolean).join("|");
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(q);
  }
  return out;
}
function chunk(a, n) { const o = []; for (let i = 0; i < a.length; i += n) o.push(a.slice(i, i + n)); return o; }
function makeUnit(title, emoji, level, questions, per = 8) {
  const lessons = chunk(questions, per).filter((q) => q.length >= 4)
    .map((qs, i) => ({ id: lid(), title: `${title} ${i + 1}`, questions: qs }));
  if (!lessons.length) return null;
  return { id: "eu" + ++lseq, title, emoji, level, lessons };
}

// ================= 데이터 =================
// 알파벳 + 그 글자로 시작하는 그림 단어들 (아이가 아는 것 위주)
const ABC = [
  ["A", "🍎", "apple", "사과"], ["B", "🐻", "bear", "곰"], ["C", "🐱", "cat", "고양이"],
  ["D", "🐶", "dog", "개"], ["E", "🐘", "elephant", "코끼리"], ["F", "🐸", "frog", "개구리"],
  ["G", "🍇", "grapes", "포도"], ["H", "🏠", "house", "집"], ["I", "🍦", "ice cream", "아이스크림"],
  ["J", "🧃", "juice", "주스"], ["K", "🔑", "key", "열쇠"], ["L", "🦁", "lion", "사자"],
  ["M", "🌙", "moon", "달"], ["N", "📓", "notebook", "공책"], ["O", "🍊", "orange", "오렌지"],
  ["P", "🐧", "penguin", "펭귄"], ["Q", "👑", "queen", "여왕"], ["R", "🌈", "rainbow", "무지개"],
  ["S", "☀️", "sun", "해"], ["T", "🐯", "tiger", "호랑이"], ["U", "☂️", "umbrella", "우산"],
  ["V", "🎻", "violin", "바이올린"], ["W", "🍉", "watermelon", "수박"], ["X", "🎄", "Xmas tree", "크리스마스트리"],
  ["Y", "🪀", "yo-yo", "요요"], ["Z", "🦓", "zebra", "얼룩말"],
];

// 파닉스 단모음 단어 (그림과 함께)
const PHONICS = [
  ["cat", "🐱", "고양이", "a"], ["hat", "🎩", "모자", "a"], ["bag", "🎒", "가방", "a"],
  ["map", "🗺️", "지도", "a"], ["fan", "🪭", "부채", "a"], ["cap", "🧢", "모자", "a"],
  ["ant", "🐜", "개미", "a"], ["ham", "🍖", "햄", "a"], ["van", "🚐", "승합차", "a"],
  ["bed", "🛏️", "침대", "e"], ["pen", "🖊️", "펜", "e"], ["net", "🥅", "그물", "e"],
  ["hen", "🐔", "암탉", "e"], ["egg", "🥚", "달걀", "e"], ["ten", "🔟", "열", "e"],
  ["pig", "🐷", "돼지", "i"], ["fish", "🐟", "물고기", "i"], ["six", "6️⃣", "여섯", "i"],
  ["lip", "👄", "입술", "i"], ["pin", "📌", "핀", "i"], ["milk", "🥛", "우유", "i"],
  ["dog", "🐶", "개", "o"], ["box", "📦", "상자", "o"], ["fox", "🦊", "여우", "o"],
  ["pot", "🍲", "냄비", "o"], ["top", "🔝", "꼭대기", "o"], ["frog", "🐸", "개구리", "o"],
  ["sun", "☀️", "해", "u"], ["bus", "🚌", "버스", "u"], ["cup", "☕", "컵", "u"],
  ["duck", "🦆", "오리", "u"], ["bug", "🐛", "벌레", "u"], ["nut", "🌰", "견과", "u"],
];

// 사이트워드 (자주 나오는 낱말)
const SIGHT = [
  ["I", "나는"], ["you", "너는"], ["he", "그는"], ["she", "그녀는"], ["we", "우리는"],
  ["is", "~이다"], ["are", "~이다(복수)"], ["am", "~이다(나)"], ["was", "~였다"],
  ["the", "그"], ["a", "하나의"], ["my", "나의"], ["your", "너의"], ["it", "그것"],
  ["and", "그리고"], ["but", "그러나"], ["or", "또는"], ["so", "그래서"],
  ["go", "가다"], ["come", "오다"], ["see", "보다"], ["look", "쳐다보다"],
  ["like", "좋아하다"], ["love", "사랑하다"], ["want", "원하다"], ["make", "만들다"],
  ["can", "할 수 있다"], ["have", "가지다"], ["get", "얻다"], ["give", "주다"],
  ["this", "이것"], ["that", "저것"], ["here", "여기"], ["there", "저기"],
  ["big", "큰"], ["small", "작은"], ["good", "좋은"], ["new", "새로운"],
  ["red", "빨간"], ["blue", "파란"], ["yes", "네"], ["no", "아니요"],
  ["up", "위로"], ["down", "아래로"], ["in", "안에"], ["on", "위에"],
];

// 그림 낱말 (주제별)
const PICTURE_WORDS = [
  // 과일·음식
  ["🍎", "apple", "사과"], ["🍌", "banana", "바나나"], ["🍓", "strawberry", "딸기"],
  ["🍊", "orange", "오렌지"], ["🍇", "grapes", "포도"], ["🍉", "watermelon", "수박"],
  ["🍑", "peach", "복숭아"], ["🥕", "carrot", "당근"], ["🌽", "corn", "옥수수"],
  ["🍪", "cookie", "쿠키"], ["🥛", "milk", "우유"], ["🍕", "pizza", "피자"],
  ["🍞", "bread", "빵"], ["🥚", "egg", "달걀"], ["🍰", "cake", "케이크"],
  ["🍦", "ice cream", "아이스크림"], ["🍬", "candy", "사탕"], ["🧃", "juice", "주스"],
  // 동물
  ["🐶", "dog", "개"], ["🐱", "cat", "고양이"], ["🐰", "rabbit", "토끼"],
  ["🐻", "bear", "곰"], ["🐷", "pig", "돼지"], ["🐸", "frog", "개구리"],
  ["🐯", "tiger", "호랑이"], ["🦁", "lion", "사자"], ["🐘", "elephant", "코끼리"],
  ["🐧", "penguin", "펭귄"], ["🦓", "zebra", "얼룩말"], ["🐴", "horse", "말"],
  ["🐮", "cow", "소"], ["🐔", "chicken", "닭"], ["🦆", "duck", "오리"],
  ["🐟", "fish", "물고기"], ["🐦", "bird", "새"], ["🦋", "butterfly", "나비"],
  // 탈것
  ["🚗", "car", "자동차"], ["🚌", "bus", "버스"], ["✈️", "airplane", "비행기"],
  ["🚂", "train", "기차"], ["🚲", "bicycle", "자전거"], ["🚢", "ship", "배"],
  // 장소·자연
  ["🏠", "house", "집"], ["🏫", "school", "학교"], ["🌳", "tree", "나무"],
  ["🌸", "flower", "꽃"], ["⭐", "star", "별"], ["🌙", "moon", "달"],
  ["☀️", "sun", "해"], ["🌧️", "rain", "비"], ["⛄", "snowman", "눈사람"],
  ["🌈", "rainbow", "무지개"], ["⛰️", "mountain", "산"], ["🌊", "sea", "바다"],
  // 물건
  ["👕", "shirt", "셔츠"], ["👟", "shoes", "신발"], ["🎒", "backpack", "가방"],
  ["✏️", "pencil", "연필"], ["📚", "book", "책"], ["🎨", "crayon", "크레용"],
  ["🪑", "chair", "의자"], ["🛏️", "bed", "침대"], ["🕐", "clock", "시계"],
  ["📦", "box", "상자"], ["🔑", "key", "열쇠"], ["☂️", "umbrella", "우산"],
  ["⚽", "ball", "공"], ["🧸", "teddy bear", "곰인형"], ["🎈", "balloon", "풍선"],
  // 몸·가족
  ["👁️", "eye", "눈"], ["👃", "nose", "코"], ["👂", "ear", "귀"],
  ["✋", "hand", "손"], ["🦶", "foot", "발"], ["👩", "mother", "엄마"],
  ["👨", "father", "아빠"], ["👶", "baby", "아기"], ["👫", "friend", "친구"],
];

// 쉬운 문장
const EASY_SENTENCES = [
  ["I like apples.", "나는 사과를 좋아해요.", "🍎"],
  ["This is my dog.", "이것은 내 개예요.", "🐶"],
  ["I can jump.", "나는 뛸 수 있어요.", "🦘"],
  ["The sun is hot.", "해는 뜨거워요.", "☀️"],
  ["I see a star.", "나는 별을 봐요.", "⭐"],
  ["My bag is red.", "내 가방은 빨간색이에요.", "🎒"],
  ["The cat is small.", "그 고양이는 작아요.", "🐱"],
  ["I go to school.", "나는 학교에 가요.", "🏫"],
  ["I have a book.", "나는 책이 있어요.", "📚"],
  ["The bus is big.", "그 버스는 커요.", "🚌"],
  ["I love my mom.", "나는 엄마를 사랑해요.", "👩"],
  ["It is a flower.", "그것은 꽃이에요.", "🌸"],
  ["I am happy.", "나는 행복해요.", "😊"],
  ["The dog is brown.", "그 개는 갈색이에요.", "🐶"],
  ["I drink milk.", "나는 우유를 마셔요.", "🥛"],
  ["Look at the moon.", "달을 봐요.", "🌙"],
  ["I have two hands.", "나는 손이 두 개예요.", "✋"],
  ["The bird can fly.", "새는 날 수 있어요.", "🐦"],
  ["I like ice cream.", "나는 아이스크림을 좋아해요.", "🍦"],
  ["My shoes are new.", "내 신발은 새것이에요.", "👟"],
  ["The fish is in the water.", "물고기가 물속에 있어요.", "🐟"],
  ["I read a book.", "나는 책을 읽어요.", "📚"],
  ["We play together.", "우리는 함께 놀아요.", "👫"],
  ["The tree is tall.", "그 나무는 커요.", "🌳"],
  ["I want a balloon.", "나는 풍선을 원해요.", "🎈"],
  ["The baby is sleeping.", "아기가 자고 있어요.", "👶"],
  ["I can see a rainbow.", "나는 무지개를 볼 수 있어요.", "🌈"],
  ["My father is tall.", "우리 아빠는 키가 커요.", "👨"],
  ["The car is fast.", "그 자동차는 빨라요.", "🚗"],
  ["I eat bread.", "나는 빵을 먹어요.", "🍞"],
  ["It is raining.", "비가 오고 있어요.", "🌧️"],
  ["The frog is green.", "개구리는 초록색이에요.", "🐸"],
  ["I ride my bicycle.", "나는 자전거를 타요.", "🚲"],
  ["She has a cat.", "그녀는 고양이가 있어요.", "🐱"],
  ["The box is small.", "그 상자는 작아요.", "📦"],
  ["I like my friend.", "나는 내 친구를 좋아해요.", "👫"],
];

// ================= 유닛 =================
const units = [];

// 1) 알파벳 대문자 찾기 (그림과 함께)
units.push(makeUnit("알파벳 찾기 (대문자)", "🔠", 1, gen(60, () => {
  const [ch, emoji, word, ko] = pick(ABC);
  const others = shuffled(ABC.filter((x) => x[0] !== ch)).slice(0, 3).map((x) => x[0]);
  return mcq(`${word} (${ko})\n첫 글자는 무엇일까요?`, ch, others,
    `${word}는 ${ch}로 시작해요. ${ch} = ${word} (${ko})`,
    { bigEmoji: emoji, skill: "vocab" });
}), 8));

// 2) 대문자 ↔ 소문자 짝
units.push(makeUnit("대문자와 소문자 짝꿍", "🔡", 1, gen(50, () => {
  const [ch] = pick(ABC);
  const lower = ch.toLowerCase();
  const others = shuffled(ABC.filter((x) => x[0] !== ch)).slice(0, 3).map((x) => x[0].toLowerCase());
  return mcq(`대문자 ${ch} 의 소문자는?`, lower, others,
    `${ch}의 소문자는 ${lower}예요. 모양이 비슷하죠?`, { skill: "vocab" });
}), 8));

// 3) 알파벳 소리 듣고 찾기
units.push(makeUnit("알파벳 소리 듣기", "🔊", 1, gen(50, () => {
  const [ch] = pick(ABC);
  const others = shuffled(ABC.filter((x) => x[0] !== ch)).slice(0, 3).map((x) => x[0]);
  return listenMcq(ch, "어떤 알파벳이 들렸나요?", ch, others,
    `들린 소리는 ${ch}예요.`);
}), 8));

// 4) 파닉스 첫소리
units.push(makeUnit("첫소리 찾기 (파닉스)", "🐣", 2, gen(50, () => {
  const [word, emoji, ko] = pick(PHONICS);
  const first = word[0].toUpperCase();
  const others = shuffled(ABC.filter((x) => x[0] !== first)).slice(0, 3).map((x) => x[0]);
  return mcq(`${ko} 그림이에요.\n${word} 의 첫소리는?`, first, others,
    `${word}는 [${word[0]}] 소리로 시작해요. 첫 글자는 ${first}예요.`,
    { bigEmoji: emoji, skill: "vocab" });
}), 8));

// 5) 파닉스 가운데 모음
units.push(makeUnit("가운데 소리 (모음)", "🎵", 2, gen(45, () => {
  const [word, emoji, ko, vowel] = pick(PHONICS);
  const others = shuffled(["a", "e", "i", "o", "u"].filter((v) => v !== vowel)).slice(0, 3);
  return mcq(`${word} (${ko})\n가운데 모음은 무엇일까요?`, vowel, others,
    `${word}의 가운데 소리는 [${vowel}]예요. 소리 내어 읽어 보세요: ${word}`,
    { bigEmoji: emoji, skill: "vocab" });
}), 8));

// 6) 그림 보고 단어 고르기
units.push(makeUnit("그림 보고 단어 찾기", "🎨", 2, gen(70, () => {
  const [emoji, word, ko] = pick(PICTURE_WORDS);
  const others = shuffled(PICTURE_WORDS.filter((x) => x[1] !== word)).slice(0, 3).map((x) => x[1]);
  return mcq(`이 그림은 영어로 무엇일까요?`, word, others,
    `${emoji} = ${word} (${ko})`, { bigEmoji: emoji, skill: "vocab" });
}), 8));

// 7) 단어 보고 뜻 고르기
units.push(makeUnit("단어 뜻 맞히기", "💡", 2, gen(60, () => {
  const [emoji, word, ko] = pick(PICTURE_WORDS);
  const others = shuffled(PICTURE_WORDS.filter((x) => x[2] !== ko)).slice(0, 3).map((x) => x[2]);
  return mcq(`"${word}" 는 무슨 뜻일까요?`, ko, others,
    `${word} = ${ko} ${emoji}`, { skill: "vocab" });
}), 8));

// 8) 그림 단어 듣기
units.push(makeUnit("듣고 그림 찾기", "🎧", 2, gen(55, () => {
  const [emoji, word, ko] = pick(PICTURE_WORDS);
  const others = shuffled(PICTURE_WORDS.filter((x) => x[2] !== ko)).slice(0, 3).map((x) => x[2]);
  return listenMcq(word, "무엇이 들렸나요?", ko, others, `${word} = ${ko} ${emoji}`);
}), 8));

// 9) 사이트워드
units.push(makeUnit("자주 나오는 낱말", "👀", 3, gen(55, () => {
  const [w, ko] = pick(SIGHT);
  const others = shuffled(SIGHT.filter((x) => x[1] !== ko)).slice(0, 3).map((x) => x[1]);
  return mcq(`"${w}" 는 무슨 뜻일까요?`, ko, others,
    `${w} = ${ko}\n책에 아주 자주 나오는 낱말이에요. 통째로 외워 두면 좋아요!`,
    { skill: "vocab" });
}), 8));

// 10) 단어 철자 쓰기 (그림 힌트)
units.push(makeUnit("단어 써 보기", "✍️", 3, gen(50, () => {
  const [emoji, word, ko] = pick(PICTURE_WORDS);
  if (word.length > 9) return null;
  return dictationQ(word, word, ko, `${emoji} ${ko} = ${word}\n철자: ${word.split("").join("-")}`);
}), 8));

// 11) 쉬운 문장 읽기
units.push(makeUnit("문장 읽기", "📖", 3, gen(40, () => {
  const [en, ko, emoji] = pick(EASY_SENTENCES);
  const others = shuffled(EASY_SENTENCES.filter((x) => x[1] !== ko)).slice(0, 3).map((x) => x[1]);
  return mcq(`"${en}"\n무슨 뜻일까요?`, ko, others, `${en}\n= ${ko}`,
    { bigEmoji: emoji, skill: "reading" });
}), 8));

// 12) 문장 따라 말하기
units.push(makeUnit("따라 말하기", "🎤", 3, gen(40, () => {
  const [en, ko] = pick(EASY_SENTENCES);
  return speakQ(en, ko);
}), 6));

// 13) 문장 듣고 받아쓰기
units.push(makeUnit("문장 받아쓰기", "📝", 3, gen(35, () => {
  const [en, ko] = pick(EASY_SENTENCES);
  return dictationQ(en, en, ko, `${en}\n= ${ko}`);
}), 6));

// ---------- 저장 ----------
const track = {
  id: "elem",
  title: "초등영어 놀이터",
  emoji: "🎠",
  color: "#FFD9A0",
  subtitle: "알파벳부터 놀면서 배우기",
  units: units.filter(Boolean),
};
const nQ = track.units.reduce((s, u) => s + u.lessons.reduce((x, l) => x + l.questions.length, 0), 0);
const nL = track.units.reduce((s, u) => s + u.lessons.length, 0);
fs.writeFileSync(path.join(OUT, "elem.json"), JSON.stringify(track), "utf8");
console.log(`elem: 유닛 ${track.units.length} · 레슨 ${nL} · 문제 ${nQ}`);
