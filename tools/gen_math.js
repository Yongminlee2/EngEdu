#!/usr/bin/env node
/**
 * 수학 문제팩 생성기.
 * tools/math/*.js 의 학년별 생성기 → app/src/main/assets/packs/math_*.json
 * 실행: node tools/gen_math.js  (프로젝트 루트에서)
 */
const fs = require("fs");
const path = require("path");

const L = require("./math/lib");
const elementary = require("./math/elementary");
const middle = require("./math/middle");
const high = require("./math/high");
const word = require("./math/word");

const OUT = path.join(__dirname, "..", "app", "src", "main", "assets", "packs");
fs.mkdirSync(OUT, { recursive: true });

// 앱의 MathGrades 와 같은 순서·이름이어야 한다
const GRADES = [
  { id: "math_k", emoji: "🐣", title: "유치원 수학", subtitle: "수 세기 · 모양 · 크기 비교", color: "#FFE0B2" },
  { id: "math_g1", emoji: "1️⃣", title: "초등 1학년 수학", subtitle: "100까지의 수 · 덧셈 뺄셈 · 시계", color: "#FFECB3" },
  { id: "math_g2", emoji: "2️⃣", title: "초등 2학년 수학", subtitle: "세 자리 수 · 곱셈구구 · 길이", color: "#F0F4C3" },
  { id: "math_g3", emoji: "3️⃣", title: "초등 3학년 수학", subtitle: "나눗셈 · 분수와 소수 · 도형", color: "#DCEDC8" },
  { id: "math_g4", emoji: "4️⃣", title: "초등 4학년 수학", subtitle: "큰 수 · 각도 · 그래프", color: "#C8E6C9" },
  { id: "math_g5", emoji: "5️⃣", title: "초등 5학년 수학", subtitle: "약수와 배수 · 분수 계산 · 넓이", color: "#B2DFDB" },
  { id: "math_g6", emoji: "6️⃣", title: "초등 6학년 수학", subtitle: "비와 비율 · 부피 · 원의 넓이", color: "#B3E5FC" },
  { id: "math_m1", emoji: "🌱", title: "중학교 1학년 수학", subtitle: "정수와 유리수 · 일차방정식 · 도형", color: "#BBDEFB" },
  { id: "math_m2", emoji: "🌿", title: "중학교 2학년 수학", subtitle: "연립방정식 · 일차함수 · 확률", color: "#C5CAE9" },
  { id: "math_m3", emoji: "🍀", title: "중학교 3학년 수학", subtitle: "이차방정식 · 이차함수 · 삼각비", color: "#D1C4E9" },
  { id: "math_h1", emoji: "🌳", title: "고등학교 1학년 수학", subtitle: "다항식 · 도형의 방정식 · 순열조합", color: "#E1BEE7" },
  { id: "math_h2", emoji: "🌲", title: "고등학교 2학년 수학", subtitle: "지수로그 · 삼각함수 · 미분과 적분", color: "#F8BBD0" },
  { id: "math_h3", emoji: "🎓", title: "고등학교 3학년 수학", subtitle: "미적분 · 확률과 통계 · 기하", color: "#FFCDD2" },
];

const BUILDERS = { ...elementary, ...middle, ...high };

const report = [];
let grand = 0;
const placement = [];

for (let i = 0; i < GRADES.length; i++) {
  const g = GRADES[i];
  const build = BUILDERS[g.id];
  if (!build) throw new Error("생성기 없음: " + g.id);

  const units = build();
  // 문장제 단원을 뒤에 붙인다 (실력 대시보드의 "문장제" 영역을 채운다)
  const wordUnit = word.unitFor(g.id, i + 1);
  if (wordUnit) units.push(wordUnit);

  const track = {
    id: g.id, title: g.title, emoji: g.emoji,
    color: g.color, subtitle: g.subtitle, units,
  };
  const nQ = units.reduce((s, u) => s + u.lessons.reduce((x, l) => x + l.questions.length, 0), 0);
  const nL = units.reduce((s, u) => s + u.lessons.length, 0);
  grand += nQ;
  report.push(`${g.id}: 유닛 ${units.length} · 레슨 ${nL} · 문제 ${nQ}`);
  fs.writeFileSync(path.join(OUT, `${g.id}.json`), JSON.stringify(track), "utf8");

  // 배치고사: 학년마다 선다형 문제를 몇 개씩 뽑아 난이도 사다리를 만든다
  const flat = units.flatMap((u) => u.lessons.flatMap((l) => l.questions));
  const choices = flat.filter((q) => q.input === "choice");
  const nums = flat.filter((q) => q.input === "number");
  const picked = [...choices.slice(0, 4), ...nums.slice(0, 6)].slice(0, 8);
  for (const q of picked) {
    placement.push({ ...q, id: "MP" + placement.length.toString().padStart(4, "0"), level: i + 1 });
  }
}

fs.writeFileSync(
  path.join(OUT, "math_placement.json"),
  JSON.stringify({ questions: placement }), "utf8"
);
report.push(`math_placement: ${placement.length}문제`);
report.push(`수학 총 문제 수: ${grand}`);
console.log(report.join("\n"));
