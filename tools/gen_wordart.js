/**
 * WordArt.kt 자동 생성기.
 *
 * drawable-nodpi 의 word_*.webp 파일과 content/vocab_L*.tsv 를 대조해
 * 영어 단어 → drawable / 한글 뜻 → drawable 색인을 만든다.
 *
 * 낱말 그림을 추가·삭제한 뒤에는 반드시 이걸 다시 돌려야 앱에 반영된다:
 *   node tools/gen_wordart.js
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const DRAWABLE = path.join(ROOT, "app/src/main/res/drawable-nodpi");
const CONTENT = path.join(ROOT, "content");
const OUT = path.join(ROOT, "app/src/main/java/com/piyak/english/engine/WordArt.kt");

// 1) 가진 그림 목록
const have = new Set(
  fs.readdirSync(DRAWABLE)
    .filter((f) => f.startsWith("word_") && f.endsWith(".webp"))
    .map((f) => f.slice(5, -5))
);

// 2) 영어 단어 → drawable (그림 파일명이 곧 단어)
const EN = [...have].sort().map((w) => [w, `word_${w}`]);

// 3) 한글 뜻 → drawable
//    오매칭을 막으려고 한 단어(1~5자)이고 여러 영단어에 겹치지 않는 뜻만 넣는다.
const koCount = new Map();
const koTo = new Map();
for (const f of fs.readdirSync(CONTENT).filter((f) => /^vocab_L\d+\.tsv$/.test(f))) {
  for (const line of fs.readFileSync(path.join(CONTENT, f), "utf8").split("\n")) {
    if (!line.trim() || line.startsWith("#")) continue;
    const [word, , ko] = line.split("\t");
    if (!word || !ko) continue;
    const w = word.trim().toLowerCase();
    if (!have.has(w)) continue;
    const meaning = ko.trim();
    // 한 낱말짜리 순수 한글 뜻만 (조사·설명이 붙은 긴 뜻은 문장 안에서 오매칭된다)
    if (!/^[가-힣]{1,5}$/.test(meaning)) continue;
    koCount.set(meaning, (koCount.get(meaning) || 0) + 1);
    koTo.set(meaning, `word_${w}`);
  }
}
const KO = [...koTo.entries()]
  .filter(([k]) => koCount.get(k) === 1)
  .sort(([a], [b]) => (a < b ? -1 : 1));

const body = `package com.piyak.english.engine

/**
 * 낱말 그림 사전 색인 (codex 발주 #02·#03·#05, 자동 생성 — tools/gen_wordart.js).
 * EN: 영어 단어 → drawable 이름 / KO: 한글 뜻 → drawable 이름.
 * 한→영은 뜻이 한 단어(1~5자)이고 중복되지 않는 것만 — 오매칭 방지.
 *
 * 그림을 추가·삭제했으면 \`node tools/gen_wordart.js\` 를 다시 돌릴 것.
 */
object WordArt {
    val EN: Map<String, String> = mapOf(
${EN.map(([k, v]) => `        "${k}" to "${v}",`).join("\n")}
    )

    val KO: Map<String, String> = mapOf(
${KO.map(([k, v]) => `        "${k}" to "${v}",`).join("\n")}
    )
}
`;

fs.writeFileSync(OUT, body, "utf8");
console.log(`WordArt.kt 생성: EN ${EN.length} · KO ${KO.length}`);
