#!/usr/bin/env node
/**
 * 팩 요약 색인 생성기.
 * 시작 화면에서 과목별 진행률을 보여주려고 팩 22개(약 27,000문제)를 전부 파싱하면
 * 앱이 켜질 때 몇 초씩 멈춘다. 레슨/문제 수만 담은 작은 색인을 미리 구워 둔다.
 *
 * 실행: node tools/gen_index.js   (gen.js / gen_math.js / gen_elem_english.js 뒤에)
 */
const fs = require("fs");
const path = require("path");

const PACKS = path.join(__dirname, "..", "app", "src", "main", "assets", "packs");

const index = {};
let grandLessons = 0;
let grandQuestions = 0;

for (const file of fs.readdirSync(PACKS)) {
  if (!file.endsWith(".json")) continue;
  if (file === "index.json") continue;
  const id = file.replace(/\.json$/, "");
  const raw = JSON.parse(fs.readFileSync(path.join(PACKS, file), "utf8"));

  // 배치고사 팩은 트랙이 아니라 문제 목록이다
  if (!raw.units) {
    index[id] = { lessons: 0, questions: (raw.questions || []).length };
    grandQuestions += index[id].questions;
    continue;
  }
  let lessons = 0;
  let questions = 0;
  for (const u of raw.units) {
    lessons += u.lessons.length;
    for (const l of u.lessons) questions += l.questions.length;
  }
  index[id] = { lessons, questions };
  grandLessons += lessons;
  grandQuestions += questions;
}

fs.writeFileSync(path.join(PACKS, "index.json"), JSON.stringify(index), "utf8");
console.log(
  `index.json: 트랙 ${Object.keys(index).length}개 · 레슨 ${grandLessons} · 문제 ${grandQuestions}`
);
