// 유치원 ~ 초등 6학년 수학 생성기
// 저학년은 그림(이모지·도형·시계)과 큰 숫자 위주, 고학년으로 갈수록 계산 중심.

const L = require("./lib");
const { rint, pick, shuffled, numQ, choiceQ, visualQ, V, FRUITS, ANIMALS, THINGS, ALL_EMOJI,
  nearWrong, makeUnit, gen } = L;

const SK = {
  calc: "m_calc", number: "m_number", shape: "m_shape",
  measure: "m_measure", data: "m_data", word: "m_word",
};

const 한글수 = ["영", "하나", "둘", "셋", "넷", "다섯", "여섯", "일곱", "여덟", "아홉", "열"];

// ================= 유치원 =================
function kindergarten() {
  const units = [];

  // 1) 1~10 수 세기 (그림)
  units.push(makeUnit("몇 개일까요? (1~10)", "🍎", 1, gen(60, () => {
    const e = pick(ALL_EMOJI);
    const n = rint(1, 10);
    return numQ(
      "그림을 세어 보세요. 모두 몇 개일까요?",
      n,
      `하나씩 세어 보면 ${한글수[n]}, 모두 ${n}개예요. ${e.repeat(Math.min(n, 10))}`,
      { visual: V.emoji(e, n), skill: SK.number }
    );
  }), 8));

  // 2) 10~20 수 세기
  units.push(makeUnit("몇 개일까요? (10~20)", "🍓", 1, gen(50, () => {
    const e = pick(ALL_EMOJI);
    const n = rint(11, 20);
    return numQ(
      "그림이 모두 몇 개인지 세어 보세요.",
      n,
      `10개씩 묶고 나머지를 세면 10 + ${n - 10} = ${n}개예요.`,
      { visual: V.emoji(e, n), skill: SK.number }
    );
  }), 8));

  // 3) 많다 / 적다
  units.push(makeUnit("어느 쪽이 더 많을까?", "⚖️", 1, gen(45, () => {
    const [e1, e2] = shuffled(ALL_EMOJI).slice(0, 2);
    let a = rint(1, 9), b = rint(1, 9);
    if (a === b) b = a + 1;
    const more = a > b ? "왼쪽" : "오른쪽";
    return choiceQ(
      "어느 쪽이 더 많을까요?",
      more, more === "왼쪽" ? ["오른쪽", "같아요", "모르겠어요"] : ["왼쪽", "같아요", "모르겠어요"],
      `왼쪽은 ${a}개, 오른쪽은 ${b}개예요. ${Math.max(a, b)}이 ${Math.min(a, b)}보다 크니까 ${more}이 더 많아요.`,
      { visual: V.compare(e1, a, e2, b), skill: SK.number }
    );
  }), 8));

  // 4) 모양 알기
  const 모양 = ["원", "삼각형", "사각형"];
  units.push(makeUnit("모양을 찾아요", "🔺", 1, gen(40, () => {
    const names = shuffled(모양).slice(0, 3);
    const target = pick(names);
    const idx = names.indexOf(target) + 1;
    return choiceQ(
      `${target} 모양은 몇 번일까요?`,
      String(idx), [1, 2, 3].filter((n) => n !== idx).map(String).concat(["없어요"]).slice(0, 3),
      `${target}은 ${target === "원" ? "동그란" : target === "삼각형" ? "뾰족한 곳이 3개인" : "네모난"} 모양이에요. ${idx}번이에요.`,
      { visual: V.shapes(names), skill: SK.shape }
    );
  }), 8));

  // 5) 다음에 올 수
  units.push(makeUnit("다음 수는 무엇일까?", "🔢", 1, gen(40, () => {
    const start = rint(1, 15);
    return numQ(
      `${start}, ${start + 1}, ${start + 2}, 다음에 올 수는?`,
      start + 3,
      `1씩 커지는 규칙이에요. ${start + 2} 다음은 ${start + 3}이에요.`,
      { visual: V.numberLine(start, start + 5, [start, start + 1, start + 2]), skill: SK.number }
    );
  }), 8));

  // 6) 반복 규칙
  units.push(makeUnit("규칙을 찾아요", "🎈", 1, gen(35, () => {
    const picked = shuffled(ALL_EMOJI);
    const [a, b] = picked;
    const others = picked.slice(2, 5); // a·b 와 겹치지 않는 오답 3개
    const pattern = `${a}${b}${a}${b}${a}`;
    return choiceQ(
      `${pattern} 다음에 올 그림은?`,
      b, others,
      `${a}와 ${b}가 번갈아 나오는 규칙이에요. ${a} 다음은 ${b}예요.`,
      { skill: SK.number }
    );
  }), 8));

  return units.filter(Boolean);
}

// ================= 초1 =================
function grade1() {
  const units = [];

  // 한 자리 덧셈 (그림)
  units.push(makeUnit("그림 덧셈", "➕", 2, gen(60, () => {
    const e = pick(ALL_EMOJI);
    const a = rint(1, 5), b = rint(1, 4);
    return numQ(
      `${a} + ${b} = ?`,
      a + b,
      `${a}개에 ${b}개를 더하면 ${a + b}개예요. ${a}에서 ${b}만큼 더 세어 보세요.`,
      { visual: V.emojiOp(e, a, b, "+"), skill: SK.calc }
    );
  }), 8));

  // 한 자리 뺄셈 (그림)
  units.push(makeUnit("그림 뺄셈", "➖", 2, gen(55, () => {
    const e = pick(ALL_EMOJI);
    const a = rint(3, 9), b = rint(1, a - 1);
    return numQ(
      `${a} - ${b} = ?`,
      a - b,
      `${a}개에서 ${b}개를 빼면 ${a - b}개가 남아요.`,
      { visual: V.emojiOp(e, a, b, "-"), skill: SK.calc }
    );
  }), 8));

  // 10 만들기
  units.push(makeUnit("10을 만들어요", "🔟", 2, gen(40, () => {
    const a = rint(1, 9);
    return numQ(
      `${a} + ___ = 10`,
      10 - a,
      `${a}에 ${10 - a}을 더하면 10이 돼요. 10을 가르면 ${a}과 ${10 - a}이에요.`,
      { visual: V.emoji("⭐", a), skill: SK.calc }
    );
  }), 8));

  // 100까지의 수
  units.push(makeUnit("100까지의 수", "💯", 2, gen(45, () => {
    const n = rint(21, 99);
    const t = Math.floor(n / 10), o = n % 10;
    return numQ(
      `10개씩 ${t}묶음과 낱개 ${o}개는 얼마일까요?`,
      n,
      `10이 ${t}개면 ${t * 10}, 여기에 ${o}을 더하면 ${n}이에요.`,
      { skill: SK.number }
    );
  }), 8));

  // 두 수의 크기 비교
  units.push(makeUnit("어느 수가 더 클까?", "⚖️", 2, gen(40, () => {
    let a = rint(10, 99), b = rint(10, 99);
    if (a === b) b += 1;
    const big = Math.max(a, b);
    return choiceQ(
      `${a}와 ${b} 중 더 큰 수는?`,
      big, [Math.min(a, b), big + 10, big - 20].filter((x) => x !== big && x > 0).slice(0, 3),
      `십의 자리부터 비교해요. ${big}이 더 커요.`,
      { skill: SK.number }
    );
  }), 8));

  // 시계 (몇 시, 몇 시 30분)
  units.push(makeUnit("몇 시일까요?", "🕐", 2, gen(40, () => {
    const h = rint(1, 12);
    const half = L.rng() < 0.5;
    const m = half ? 30 : 0;
    return choiceQ(
      "시계를 보고 몇 시인지 골라 보세요.",
      half ? `${h}시 30분` : `${h}시`,
      shuffled([
        `${h === 12 ? 1 : h + 1}시`, `${h}시 ${half ? "" : "30분"}`.trim(),
        `${h === 1 ? 12 : h - 1}시 30분`, `${h}시 15분`,
      ]).filter((x) => x !== (half ? `${h}시 30분` : `${h}시`)).slice(0, 3),
      half
        ? `짧은바늘이 ${h}과 ${h === 12 ? 1 : h + 1} 사이, 긴바늘이 6을 가리키면 ${h}시 30분이에요.`
        : `짧은바늘이 ${h}, 긴바늘이 12를 가리키면 ${h}시예요.`,
      { visual: V.clock(h, m), skill: SK.measure }
    );
  }), 8));

  // 시계를 읽는 것에서 한 걸음 더 — 바늘을 직접 돌려 시각을 만들어 본다
  units.push(makeUnit("시계 바늘 돌리기", "🕐", 2, gen(30, () => {
    const h = rint(1, 12);
    const half = L.rng() < 0.5;
    const m = half ? 30 : 0;
    const label = half ? `${h}시 30분` : `${h}시`;
    return visualQ(
      `시계 바늘을 끌어서 ${label}을 만들어 보세요.`,
      `${h}:${m}`,
      `짧은바늘을 ${h}에, 긴바늘을 ${half ? 6 : 12}에 놓으면 ${label}이에요.`,
      { visual: V.clockSet(h, m), skill: SK.measure }
    );
  }), 6));

  return units.filter(Boolean);
}

// ================= 초2 =================
function grade2() {
  const units = [];

  units.push(makeUnit("받아올림 덧셈", "➕", 3, gen(55, () => {
    const a = rint(11, 89), b = rint(11, 89);
    return numQ(`${a} + ${b} = ?`, a + b,
      `일의 자리 ${a % 10} + ${b % 10} = ${(a % 10) + (b % 10)}${(a % 10) + (b % 10) >= 10 ? " (10 넘으면 십의 자리로 받아올림!)" : ""}\n답은 ${a + b}이에요.`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("받아내림 뺄셈", "➖", 3, gen(55, () => {
    const a = rint(30, 99), b = rint(11, a - 1);
    return numQ(`${a} - ${b} = ?`, a - b,
      `${a % 10 < b % 10 ? "일의 자리를 뺄 수 없으니 십의 자리에서 10을 빌려와요. " : ""}답은 ${a - b}이에요.`,
      { skill: SK.calc });
  }), 10));

  // 곱셈구구 (배열 그림)
  for (const dan of [2, 3, 4, 5, 6, 7, 8, 9]) {
    units.push(makeUnit(`${dan}단 곱셈구구`, "✖️", 3, gen(18, () => {
      const b = rint(1, 9);
      const e = pick(ANIMALS);
      return numQ(`${dan} × ${b} = ?`, dan * b,
        `${dan}씩 ${b}묶음이에요. ${Array(b).fill(dan).join(" + ")} = ${dan * b}\n${dan}단: ${dan}×${b}=${dan * b}`,
        { visual: V.array(e, dan, b), skill: SK.calc });
    }), 9));
  }

  units.push(makeUnit("세 자리 수", "🔢", 3, gen(35, () => {
    const n = rint(101, 999);
    const h = Math.floor(n / 100), t = Math.floor(n / 10) % 10, o = n % 10;
    return numQ(`100이 ${h}개, 10이 ${t}개, 1이 ${o}개인 수는?`, n,
      `${h * 100} + ${t * 10} + ${o} = ${n}이에요.`, { skill: SK.number });
  }), 8));

  units.push(makeUnit("길이 재기 (cm·m)", "📏", 3, gen(35, () => {
    const m = rint(1, 5), cm = rint(1, 99);
    return numQ(`${m}m ${cm}cm는 몇 cm일까요?`, m * 100 + cm,
      `1m는 100cm예요. ${m}m = ${m * 100}cm, 여기에 ${cm}cm를 더하면 ${m * 100 + cm}cm예요.`,
      { unit: "cm", skill: SK.measure });
  }), 8));

  units.push(makeUnit("몇 시 몇 분", "🕐", 3, gen(35, () => {
    const h = rint(1, 12), m = rint(1, 11) * 5;
    return numQ(`시계가 ${h}시 몇 분을 가리키고 있을까요? (분만 쓰세요)`, m,
      `긴바늘이 ${m / 5}를 가리키면 ${m / 5} × 5 = ${m}분이에요.`,
      { visual: V.clock(h, m), unit: "분", skill: SK.measure });
  }), 8));

  units.push(makeUnit("시계 바늘 돌리기 (5분)", "🕐", 3, gen(30, () => {
    const h = rint(1, 12), m = rint(1, 11) * 5;
    return visualQ(
      `시계 바늘을 끌어서 ${h}시 ${m}분을 만들어 보세요.`,
      `${h}:${m}`,
      `긴바늘은 ${m} ÷ 5 = ${m / 5}, 즉 숫자 ${m / 5}에 놓아요.\n짧은바늘은 ${h}에 놓으면 ${h}시 ${m}분이에요.`,
      { visual: V.clockSet(h, m), skill: SK.measure }
    );
  }), 6));

  units.push(makeUnit("표와 그래프", "📊", 3, gen(30, () => {
    const labels = shuffled(["사과", "포도", "딸기", "바나나"]).slice(0, 4);
    const values = labels.map(() => rint(1, 9));
    const maxI = values.indexOf(Math.max(...values));
    return choiceQ("가장 많은 것은 무엇일까요?", labels[maxI],
      labels.filter((_, i) => i !== maxI),
      `막대가 가장 높은 것을 찾아요. ${labels[maxI]}이(가) ${values[maxI]}개로 가장 많아요.`,
      { visual: V.barGraph(labels, values), skill: SK.data });
  }), 8));

  return units.filter(Boolean);
}

// ================= 초3 =================
function grade3() {
  const units = [];

  units.push(makeUnit("나눗셈 (똑같이 나누기)", "➗", 4, gen(50, () => {
    const b = rint(2, 9), q = rint(2, 9);
    const a = b * q;
    const e = pick(ANIMALS);
    return numQ(`${a} ÷ ${b} = ?`, q,
      `${a}개를 ${b}묶음으로 똑같이 나누면 한 묶음에 ${q}개예요.\n확인: ${b} × ${q} = ${a}`,
      { visual: V.array(e, b, q), skill: SK.calc });
  }), 10));

  // 나눗셈을 계산하기 전에 실제로 나눠 담아 본다 (끌어서 바구니에)
  units.push(makeUnit("끌어서 똑같이 나누기", "🧺", 4, gen(30, () => {
    const b = rint(2, 4);            // 바구니 수
    const q = rint(2, 5);            // 한 바구니에 담길 개수
    const a = b * q;
    if (a > 18) return null;         // 화면에 한눈에 들어오는 만큼만
    const e = pick(ANIMALS);
    return visualQ(
      `${e} ${a}마리를 바구니 ${b}개에 똑같이 나눠 담아 보세요. (${a} ÷ ${b})`,
      q,
      `${a}개를 ${b}묶음으로 똑같이 나누면 한 묶음에 ${q}개예요.\n확인: ${b} × ${q} = ${a}\n그래서 ${a} ÷ ${b} = ${q}예요.`,
      { visual: V.group(e, a, b), skill: SK.calc }
    );
  }), 6));

  units.push(makeUnit("두 자리 × 한 자리", "✖️", 4, gen(45, () => {
    const a = rint(11, 99), b = rint(2, 9);
    return numQ(`${a} × ${b} = ?`, a * b,
      `${a}를 ${Math.floor(a / 10) * 10}와 ${a % 10}으로 나눠 곱해요.\n${Math.floor(a / 10) * 10}×${b}=${Math.floor(a / 10) * 10 * b}, ${a % 10}×${b}=${(a % 10) * b}\n합하면 ${a * b}이에요.`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("분수 알아보기", "🍰", 4, gen(40, () => {
    const d = rint(2, 8), n = rint(1, d - 1);
    return numQ(`색칠한 부분은 전체의 몇 분의 몇일까요? (분자만 쓰세요)`, n,
      `전체를 똑같이 ${d}로 나눈 것 중 ${n}칸이 색칠됐어요. 그래서 ${n}/${d}이에요.`,
      { visual: V.fraction(n, d), skill: SK.number });
  }), 8));

  units.push(makeUnit("소수 알아보기", "0️⃣", 4, gen(35, () => {
    const n = rint(1, 9);
    return numQ(`1을 똑같이 10으로 나눈 것 중 ${n}개는 소수로 얼마일까요?`, `0.${n}`,
      `10칸 중 ${n}칸이니까 ${n}/10 = 0.${n}이에요.`,
      { visual: V.fraction(n, 10), skill: SK.number });
  }), 8));

  units.push(makeUnit("직각과 평면도형", "📐", 4, gen(35, () => {
    const names = shuffled(["삼각형", "사각형", "오각형", "육각형"]).slice(0, 3);
    const target = pick(names);
    const sides = { 삼각형: 3, 사각형: 4, 오각형: 5, 육각형: 6 }[target];
    return numQ(`${target}의 변은 몇 개일까요?`, sides,
      `${target}은 변이 ${sides}개, 꼭짓점도 ${sides}개예요.`,
      { visual: V.shapes(names), skill: SK.shape });
  }), 8));

  units.push(makeUnit("길이와 시간", "⏱️", 4, gen(35, () => {
    if (L.rng() < 0.5) {
      const km = rint(1, 9), m = rint(1, 999);
      return numQ(`${km}km ${m}m는 몇 m일까요?`, km * 1000 + m,
        `1km는 1000m예요. ${km * 1000} + ${m} = ${km * 1000 + m}m`,
        { unit: "m", skill: SK.measure });
    }
    const min = rint(1, 9), sec = rint(1, 59);
    return numQ(`${min}분 ${sec}초는 몇 초일까요?`, min * 60 + sec,
      `1분은 60초예요. ${min}×60 = ${min * 60}, ${min * 60} + ${sec} = ${min * 60 + sec}초`,
      { unit: "초", skill: SK.measure });
  }), 8));

  units.push(makeUnit("무게와 들이", "⚖️", 4, gen(30, () => {
    if (L.rng() < 0.5) {
      const kg = rint(1, 9), g = rint(1, 999);
      return numQ(`${kg}kg ${g}g은 몇 g일까요?`, kg * 1000 + g,
        `1kg은 1000g이에요. ${kg * 1000} + ${g} = ${kg * 1000 + g}g`,
        { unit: "g", skill: SK.measure });
    }
    const l = rint(1, 9), ml = rint(1, 999);
    return numQ(`${l}L ${ml}mL는 몇 mL일까요?`, l * 1000 + ml,
      `1L는 1000mL예요. ${l * 1000} + ${ml} = ${l * 1000 + ml}mL`,
      { unit: "mL", skill: SK.measure });
  }), 8));

  return units.filter(Boolean);
}

// ================= 초4 =================
function grade4() {
  const units = [];

  units.push(makeUnit("큰 수", "🔢", 5, gen(35, () => {
    const man = rint(1, 9999);
    return numQ(`${man}만은 0이 몇 개 붙을까요? (만은 10000)`, 4,
      `1만 = 10000, 0이 4개예요. ${man}만 = ${man * 10000}`, { skill: SK.number });
  }), 8));

  units.push(makeUnit("각도 재기", "📐", 5, gen(40, () => {
    const deg = rint(2, 34) * 5;
    const kind = deg < 90 ? "예각" : deg === 90 ? "직각" : "둔각";
    return choiceQ(`이 각은 어떤 각일까요? (${deg}°)`, kind,
      ["예각", "직각", "둔각", "평각"].filter((x) => x !== kind).slice(0, 3),
      `${deg}°는 ${deg < 90 ? "90°보다 작으니 예각" : deg === 90 ? "정확히 90°라 직각" : "90°보다 크고 180°보다 작으니 둔각"}이에요.`,
      { visual: V.angle(deg), skill: SK.shape });
  }), 8));

  units.push(makeUnit("세 자리 × 두 자리", "✖️", 5, gen(40, () => {
    const a = rint(101, 999), b = rint(11, 99);
    return numQ(`${a} × ${b} = ?`, a * b,
      `${a} × ${b % 10} = ${a * (b % 10)}\n${a} × ${Math.floor(b / 10) * 10} = ${a * Math.floor(b / 10) * 10}\n합하면 ${a * b}이에요.`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("나눗셈 (몫과 나머지)", "➗", 5, gen(40, () => {
    const b = rint(2, 9), q = rint(11, 99), r = rint(0, b - 1);
    const a = b * q + r;
    return numQ(`${a} ÷ ${b}의 나머지는?`, r,
      `${a} ÷ ${b} = ${q} … ${r}\n확인: ${b} × ${q} + ${r} = ${a}`, { skill: SK.calc });
  }), 10));

  units.push(makeUnit("분수의 덧셈과 뺄셈", "🍰", 5, gen(40, () => {
    const d = rint(3, 9);
    const a = rint(1, d - 1), b = rint(1, d - a);
    return numQ(`${a}/${d} + ${b}/${d} = ? (분자만 쓰세요)`, a + b,
      `분모가 같으면 분자끼리 더해요. ${a} + ${b} = ${a + b}, 답은 ${a + b}/${d}예요.`,
      { visual: V.fraction(a + b, d), skill: SK.calc });
  }), 8));

  units.push(makeUnit("소수의 덧셈과 뺄셈", "0️⃣", 5, gen(35, () => {
    const a = rint(1, 99) / 10, b = rint(1, 99) / 10;
    const ans = Math.round((a + b) * 10) / 10;
    return numQ(`${a} + ${b} = ?`, ans,
      `소수점 자리를 맞춰 더해요. ${a} + ${b} = ${ans}`, { skill: SK.calc });
  }), 8));

  units.push(makeUnit("막대그래프 읽기", "📊", 5, gen(35, () => {
    const labels = shuffled(["월", "화", "수", "목"]).slice(0, 4);
    const values = labels.map(() => rint(2, 20));
    const i = rint(0, 3);
    return numQ(`${labels[i]}요일의 값은 얼마일까요?`, values[i],
      `${labels[i]}요일 막대의 높이를 눈금에서 읽으면 ${values[i]}이에요.`,
      { visual: V.barGraph(labels, values), skill: SK.data });
  }), 8));

  return units.filter(Boolean);
}

// ================= 초5 =================
function grade5() {
  const units = [];

  units.push(makeUnit("자연수의 혼합 계산", "🧮", 6, gen(45, () => {
    const a = rint(2, 20), b = rint(2, 9), c = rint(2, 9);
    return numQ(`${a} + ${b} × ${c} = ?`, a + b * c,
      `곱셈을 먼저 해요. ${b} × ${c} = ${b * c}, 그다음 ${a} + ${b * c} = ${a + b * c}`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("약수와 배수", "🔢", 6, gen(45, () => {
    const a = rint(4, 48), b = rint(4, 48);
    const g = gcd(a, b);
    return numQ(`${a}와 ${b}의 최대공약수는?`, g,
      `${a}의 약수와 ${b}의 약수 중 가장 큰 공통 약수는 ${g}이에요.`, { skill: SK.number });
  }), 10));

  units.push(makeUnit("약분과 통분", "🍰", 6, gen(40, () => {
    const g = rint(2, 6), n = rint(1, 8), d = n + rint(1, 8);
    return numQ(`${n * g}/${d * g}를 기약분수로 나타내면 분자는?`, n,
      `분자와 분모를 최대공약수 ${g}로 나눠요. ${n * g}÷${g}=${n}, ${d * g}÷${g}=${d}\n답은 ${n}/${d}예요.`,
      { visual: V.fraction(n, d), skill: SK.number });
  }), 8));

  units.push(makeUnit("분수의 곱셈", "✖️", 6, gen(40, () => {
    const a = rint(1, 5), b = rint(2, 7), c = rint(1, 5), d = rint(2, 7);
    const [rn, rd] = reduce(a * c, b * d);
    return numQ(`${a}/${b} × ${c}/${d} = ? (기약분수의 분자)`, rn,
      `분자끼리, 분모끼리 곱해요. ${a}×${c}=${a * c}, ${b}×${d}=${b * d}\n${a * c}/${b * d}를 약분하면 ${rn}/${rd}예요.`,
      { skill: SK.calc });
  }), 8));

  units.push(makeUnit("다각형의 넓이", "📐", 6, gen(40, () => {
    const t = L.rng();
    if (t < 0.4) {
      const w = rint(2, 20), h = rint(2, 20);
      return numQ(`가로 ${w}cm, 세로 ${h}cm인 직사각형의 넓이는?`, w * h,
        `직사각형의 넓이 = 가로 × 세로 = ${w} × ${h} = ${w * h}cm²`,
        { unit: "cm²", skill: SK.measure });
    } else if (t < 0.7) {
      const b = rint(2, 10) * 2, h = rint(2, 15);
      return numQ(`밑변 ${b}cm, 높이 ${h}cm인 삼각형의 넓이는?`, (b * h) / 2,
        `삼각형의 넓이 = 밑변 × 높이 ÷ 2 = ${b} × ${h} ÷ 2 = ${(b * h) / 2}cm²`,
        { unit: "cm²", skill: SK.measure });
    }
    const a = rint(2, 12), b = rint(2, 12), h = rint(2, 10) * 2;
    return numQ(`윗변 ${a}cm, 아랫변 ${b}cm, 높이 ${h}cm인 사다리꼴의 넓이는?`, ((a + b) * h) / 2,
      `사다리꼴 넓이 = (윗변 + 아랫변) × 높이 ÷ 2 = (${a}+${b}) × ${h} ÷ 2 = ${((a + b) * h) / 2}cm²`,
      { unit: "cm²", skill: SK.measure });
  }), 8));

  units.push(makeUnit("평균 구하기", "📊", 6, gen(35, () => {
    const n = rint(3, 5);
    const vals = Array.from({ length: n }, () => rint(1, 20));
    const sum = vals.reduce((s, v) => s + v, 0);
    if (sum % n !== 0) vals[0] += n - (sum % n);
    const total2 = vals.reduce((s, v) => s + v, 0);
    return numQ(`${vals.join(", ")}의 평균은?`, total2 / n,
      `모두 더하면 ${total2}, 자료가 ${n}개니까 ${total2} ÷ ${n} = ${total2 / n}이에요.`,
      { visual: V.barGraph(vals.map((_, i) => `${i + 1}`), vals), skill: SK.data });
  }), 8));

  return units.filter(Boolean);
}

// ================= 초6 =================
function grade6() {
  const units = [];

  units.push(makeUnit("분수의 나눗셈", "➗", 7, gen(45, () => {
    const a = rint(1, 6), b = rint(2, 9), c = rint(1, 6), d = rint(2, 9);
    const [rn, rd] = reduce(a * d, b * c);
    return numQ(`${a}/${b} ÷ ${c}/${d} = ? (기약분수의 분자)`, rn,
      `나눗셈은 뒤 분수를 뒤집어 곱해요. ${a}/${b} × ${d}/${c} = ${a * d}/${b * c}\n약분하면 ${rn}/${rd}예요.`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("소수의 나눗셈", "0️⃣", 7, gen(40, () => {
    const b = rint(2, 9), q = rint(2, 50);
    const a = Math.round(b * q * 10) / 10;
    return numQ(`${(a / 10).toFixed(1)} ÷ ${b} = ?`, Math.round((a / 10 / b) * 100) / 100,
      `소수점을 옮겨 계산해요. ${(a / 10).toFixed(1)} ÷ ${b} = ${Math.round((a / 10 / b) * 100) / 100}`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("비와 비율", "⚖️", 7, gen(40, () => {
    const a = rint(1, 9), k = rint(2, 9);
    const b = a * k;
    return numQ(`${a} : ${b}를 가장 간단한 자연수의 비로 나타내면 ${1} : ?`, k,
      `두 수를 최대공약수 ${a}로 나눠요. ${a}÷${a}=1, ${b}÷${a}=${k}\n답은 1 : ${k}예요.`,
      { skill: SK.number });
  }), 8));

  units.push(makeUnit("백분율", "💯", 7, gen(35, () => {
    const total = rint(2, 20) * 10;
    const part = Math.round(total * rint(1, 9) / 10);
    const pct = Math.round((part / total) * 100);
    return numQ(`전체 ${total} 중 ${part}은 몇 %일까요?`, pct,
      `비율 = ${part} ÷ ${total} = ${(part / total).toFixed(2)}\n백분율은 100을 곱해서 ${pct}%예요.`,
      { unit: "%", skill: SK.number });
  }), 8));

  units.push(makeUnit("원의 넓이와 둘레", "⭕", 7, gen(40, () => {
    const r = rint(1, 15);
    if (L.rng() < 0.5) {
      return numQ(`반지름이 ${r}cm인 원의 넓이는? (원주율 3.14)`, Math.round(3.14 * r * r * 100) / 100,
        `원의 넓이 = 반지름 × 반지름 × 3.14 = ${r} × ${r} × 3.14 = ${Math.round(3.14 * r * r * 100) / 100}cm²`,
        { unit: "cm²", skill: SK.measure });
    }
    return numQ(`반지름이 ${r}cm인 원의 둘레는? (원주율 3.14)`, Math.round(2 * 3.14 * r * 100) / 100,
      `원의 둘레 = 지름 × 3.14 = ${2 * r} × 3.14 = ${Math.round(2 * 3.14 * r * 100) / 100}cm`,
      { unit: "cm", skill: SK.measure });
  }), 8));

  units.push(makeUnit("직육면체의 부피와 겉넓이", "🧊", 7, gen(40, () => {
    const a = rint(2, 12), b = rint(2, 12), c = rint(2, 12);
    if (L.rng() < 0.5) {
      return numQ(`가로 ${a}cm, 세로 ${b}cm, 높이 ${c}cm인 직육면체의 부피는?`, a * b * c,
        `부피 = 가로 × 세로 × 높이 = ${a} × ${b} × ${c} = ${a * b * c}cm³`,
        { unit: "cm³", skill: SK.measure });
    }
    const s = 2 * (a * b + b * c + a * c);
    return numQ(`가로 ${a}cm, 세로 ${b}cm, 높이 ${c}cm인 직육면체의 겉넓이는?`, s,
      `겉넓이 = 2 × (${a}×${b} + ${b}×${c} + ${a}×${c}) = 2 × ${a * b + b * c + a * c} = ${s}cm²`,
      { unit: "cm²", skill: SK.measure });
  }), 8));

  units.push(makeUnit("여러 가지 그래프", "📊", 7, gen(30, () => {
    const labels = shuffled(["A반", "B반", "C반", "D반"]).slice(0, 4);
    const values = labels.map(() => rint(5, 40));
    const sum = values.reduce((s, v) => s + v, 0);
    return numQ(`네 반의 학생 수를 모두 더하면 몇 명일까요?`, sum,
      `${values.join(" + ")} = ${sum}명이에요.`,
      { visual: V.barGraph(labels, values), unit: "명", skill: SK.data });
  }), 8));

  return units.filter(Boolean);
}

// ---------- 도우미 ----------
function gcd(a, b) { return b === 0 ? a : gcd(b, a % b); }
function reduce(n, d) {
  const g = gcd(n, d) || 1;
  return [n / g, d / g];
}

module.exports = {
  math_k: kindergarten,
  math_g1: grade1,
  math_g2: grade2,
  math_g3: grade3,
  math_g4: grade4,
  math_g5: grade5,
  math_g6: grade6,
};
