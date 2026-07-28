// 중학교 1~3학년 수학 생성기
const L = require("./lib");
const { rint, pick, shuffled, numQ, choiceQ, textQ, visualQ, V, nearWrong, makeUnit, gen } = L;

const SK = {
  calc: "m_calc", number: "m_number", shape: "m_shape",
  measure: "m_measure", data: "m_data", word: "m_word",
};

function gcd(a, b) { return b === 0 ? Math.abs(a) : gcd(b, a % b); }
function reduce(n, d) { const g = gcd(n, d) || 1; return [n / g, d / g]; }
function primeFactors(n) {
  const out = [];
  let x = n;
  for (let p = 2; p * p <= x; p++) while (x % p === 0) { out.push(p); x /= p; }
  if (x > 1) out.push(x);
  return out;
}
/** ax + b = c 형태를 정수해가 나오게 만든다 */
function linearEq() {
  const a = rint(2, 9), x = rint(-9, 9), b = rint(-15, 15);
  return { a, b, x, c: a * x + b };
}

// ================= 중1 =================
function middle1() {
  const units = [];

  units.push(makeUnit("소인수분해", "🔢", 8, gen(40, () => {
    const n = rint(12, 200);
    const f = primeFactors(n);
    return numQ(`${n}을 소인수분해했을 때 가장 큰 소인수는?`, Math.max(...f),
      `${n} = ${f.join(" × ")}\n가장 큰 소인수는 ${Math.max(...f)}이에요.`, { skill: SK.number });
  }), 10));

  units.push(makeUnit("정수와 유리수의 계산", "➕", 8, gen(50, () => {
    const a = rint(-20, 20), b = rint(-20, 20);
    const t = L.rng();
    if (t < 0.5) {
      return numQ(`(${a}) + (${b}) = ?`, a + b,
        `부호를 살펴요. ${a} + ${b} = ${a + b}\n${a < 0 && b < 0 ? "둘 다 음수면 절댓값을 더하고 음수 부호를 붙여요." : "부호가 다르면 절댓값이 큰 쪽 부호를 따라요."}`,
        { skill: SK.calc });
    }
    return numQ(`(${a}) × (${b}) = ?`, a * b,
      `부호 규칙: (음)×(음)=(양), (음)×(양)=(음)\n${a} × ${b} = ${a * b}`, { skill: SK.calc });
  }), 10));

  units.push(makeUnit("문자와 식", "✏️", 8, gen(40, () => {
    const a = rint(2, 9), b = rint(2, 9), x = rint(1, 9);
    return numQ(`x = ${x}일 때, ${a}x + ${b}의 값은?`, a * x + b,
      `x 자리에 ${x}를 넣어요. ${a} × ${x} + ${b} = ${a * x} + ${b} = ${a * x + b}`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("일차방정식", "🟰", 8, gen(50, () => {
    const { a, b, c, x } = linearEq();
    return numQ(`${a}x ${b >= 0 ? "+ " + b : "- " + -b} = ${c} 일 때 x는?`, x,
      `양변에서 ${b}를 ${b >= 0 ? "빼면" : "더하면"} ${a}x = ${c - b}\n양변을 ${a}로 나누면 x = ${x}예요.`,
      { skill: SK.calc });
  }), 10));

  // 이항을 외우기 전에 "양쪽이 같다"는 등식의 뜻을 저울로 본다
  units.push(makeUnit("저울로 방정식 풀기", "⚖️", 8, gen(30, () => {
    const a = rint(2, 5);          // x 상자 개수
    const x = rint(2, 8);          // 정답
    const b = rint(1, 9);          // 왼쪽 추
    const c = a * x + b;           // 오른쪽 추
    if (c > 45) return null;       // 추가 너무 많으면 접시가 복잡해진다
    return visualQ(
      `저울이 평형이 되도록 x 를 맞춰 보세요. (${a}x + ${b} = ${c})`,
      x,
      `왼쪽은 x 상자 ${a}개와 1짜리 추 ${b}개, 오른쪽은 1짜리 추 ${c}개예요.\n` +
      `양쪽에서 ${b}을 덜어내면 ${a}x = ${c - b}\n` +
      `${a}묶음으로 똑같이 나누면 x = ${x}예요.`,
      { visual: V.balance(a, b, c), skill: SK.calc }
    );
  }), 6));

  // 음수를 "0보다 작은 수"로만 외우지 않도록 수직선 위에서 직접 짚는다
  units.push(makeUnit("수직선에서 정수 찾기", "📏", 8, gen(24, () => {
    const target = rint(-10, 10);
    // 0 은 시작점 표시와 겹치고, -10 은 점이 처음 놓인 자리라 움직이지 않아도 맞아 버린다
    if (target === 0 || target === -10) return null;
    return visualQ(
      `수직선에서 ${target} 을 찾아 점을 놓아 보세요.`,
      target,
      target < 0
        ? `${target} 은 0 보다 ${-target} 만큼 작아요. 0 에서 왼쪽으로 ${-target} 칸 가면 돼요.`
        : `${target} 은 0 에서 오른쪽으로 ${target} 칸 간 자리예요.`,
      { visual: V.numberLineDrag(-10, 10, 20), skill: SK.number }
    );
  }), 5));

  units.push(makeUnit("정비례와 반비례", "📈", 8, gen(35, () => {
    const k = rint(2, 12), x = rint(2, 9);
    if (L.rng() < 0.5) {
      return numQ(`y = ${k}x 에서 x = ${x}일 때 y는?`, k * x,
        `정비례식에 x = ${x}를 넣어요. y = ${k} × ${x} = ${k * x}`, { skill: SK.calc });
    }
    const prod = k * x;
    return numQ(`y = ${prod}/x 에서 x = ${x}일 때 y는?`, k,
      `반비례식에 x = ${x}를 넣어요. y = ${prod} ÷ ${x} = ${k}`, { skill: SK.calc });
  }), 8));

  units.push(makeUnit("평면도형의 성질", "📐", 8, gen(40, () => {
    const n = rint(3, 12);
    if (L.rng() < 0.5) {
      return numQ(`${n}각형의 내각의 크기의 합은? (단위 °)`, (n - 2) * 180,
        `n각형의 내각의 합 = (n - 2) × 180°\n(${n} - 2) × 180 = ${(n - 2) * 180}°`,
        { unit: "°", skill: SK.shape });
    }
    return numQ(`${n}각형의 대각선의 개수는?`, (n * (n - 3)) / 2,
      `대각선 개수 = n(n-3)/2 = ${n}×${n - 3}/2 = ${(n * (n - 3)) / 2}개`, { skill: SK.shape });
  }), 8));

  units.push(makeUnit("입체도형의 겉넓이와 부피", "🧊", 8, gen(35, () => {
    const r = rint(2, 9), h = rint(2, 12);
    return numQ(`밑면의 반지름 ${r}, 높이 ${h}인 원기둥의 부피는? (원주율 3.14)`,
      Math.round(3.14 * r * r * h * 100) / 100,
      `원기둥의 부피 = 밑넓이 × 높이 = (${r}×${r}×3.14) × ${h} = ${Math.round(3.14 * r * r * h * 100) / 100}`,
      { skill: SK.measure });
  }), 8));

  units.push(makeUnit("자료의 정리와 해석", "📊", 8, gen(30, () => {
    const labels = ["10대", "20대", "30대", "40대"];
    const values = labels.map(() => rint(3, 25));
    const sum = values.reduce((s, v) => s + v, 0);
    const i = rint(0, 3);
    return numQ(`${labels[i]}의 상대도수는? (소수 둘째 자리까지)`,
      Math.round((values[i] / sum) * 100) / 100,
      `상대도수 = 그 계급의 도수 ÷ 전체 도수 = ${values[i]} ÷ ${sum} ≈ ${Math.round((values[i] / sum) * 100) / 100}`,
      { visual: V.barGraph(labels, values), skill: SK.data });
  }), 8));

  return units.filter(Boolean);
}

// ================= 중2 =================
function middle2() {
  const units = [];

  units.push(makeUnit("지수법칙", "🔢", 9, gen(45, () => {
    const a = rint(2, 9), m = rint(2, 6), n = rint(2, 6);
    if (L.rng() < 0.5) {
      return numQ(`${a}^${m} × ${a}^${n} 을 ${a}^k 로 나타낼 때 k는?`, m + n,
        `밑이 같은 거듭제곱의 곱은 지수를 더해요. ${m} + ${n} = ${m + n}`, { skill: SK.calc });
    }
    return numQ(`(${a}^${m})^${n} 을 ${a}^k 로 나타낼 때 k는?`, m * n,
      `거듭제곱의 거듭제곱은 지수를 곱해요. ${m} × ${n} = ${m * n}`, { skill: SK.calc });
  }), 10));

  units.push(makeUnit("일차부등식", "⚖️", 9, gen(40, () => {
    const a = rint(2, 9), x = rint(-8, 8), b = rint(-12, 12);
    const c = a * x + b;
    return numQ(`${a}x ${b >= 0 ? "+ " + b : "- " + -b} > ${c} 를 만족하는 x의 범위는 x > ? `, x,
      `양변에서 ${b}를 ${b >= 0 ? "빼면" : "더하면"} ${a}x > ${c - b}\n양변을 양수 ${a}로 나누면 x > ${x}\n(음수로 나눌 때는 부등호 방향이 바뀌어요!)`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("연립방정식", "🟰", 9, gen(45, () => {
    const x = rint(-6, 8), y = rint(-6, 8);
    const a = rint(1, 5), b = rint(1, 5), c = rint(1, 5), d = rint(1, 5);
    if (a * d - b * c === 0) return null;
    return numQ(
      `${a}x + ${b}y = ${a * x + b * y}\n${c}x + ${d}y = ${c * x + d * y}\n일 때 x의 값은?`,
      x,
      `가감법으로 y를 없애요.\n첫 식 × ${d}, 둘째 식 × ${b} 한 뒤 빼면 x = ${x}\n대입하면 y = ${y}예요.`,
      { skill: SK.calc }
    );
  }), 10));

  units.push(makeUnit("일차함수와 그래프", "📈", 9, gen(45, () => {
    const a = rint(-5, 5) || 2, b = rint(-9, 9), x = rint(-5, 5);
    const t = L.rng();
    if (t < 0.5) {
      return numQ(`y = ${a}x ${b >= 0 ? "+ " + b : "- " + -b} 에서 x = ${x}일 때 y는?`, a * x + b,
        `x = ${x}을 대입해요. y = ${a}×${x} ${b >= 0 ? "+ " + b : "- " + -b} = ${a * x + b}`,
        { skill: SK.calc });
    }
    return numQ(`y = ${a}x ${b >= 0 ? "+ " + b : "- " + -b} 의 y절편은?`, b,
      `y절편은 x = 0일 때의 y값이에요. y = ${b}\n기울기는 ${a}이고요.`, { skill: SK.calc });
  }), 10));

  units.push(makeUnit("피타고라스 정리", "📐", 9, gen(40, () => {
    const triples = [[3, 4, 5], [6, 8, 10], [5, 12, 13], [8, 15, 17], [9, 12, 15], [7, 24, 25], [20, 21, 29]];
    const [a, b, c] = pick(triples);
    const k = rint(1, 3);
    if (L.rng() < 0.6) {
      return numQ(`직각삼각형의 두 변이 ${a * k}, ${b * k}일 때 빗변의 길이는?`, c * k,
        `피타고라스 정리: a² + b² = c²\n${a * k}² + ${b * k}² = ${(a * k) ** 2} + ${(b * k) ** 2} = ${(c * k) ** 2}\n빗변 = ${c * k}`,
        { skill: SK.shape });
    }
    return numQ(`빗변이 ${c * k}, 한 변이 ${a * k}인 직각삼각형의 나머지 변은?`, b * k,
      `c² - a² = b²\n${(c * k) ** 2} - ${(a * k) ** 2} = ${(b * k) ** 2}\n나머지 변 = ${b * k}`,
      { skill: SK.shape });
  }), 10));

  units.push(makeUnit("도형의 닮음", "🔺", 9, gen(35, () => {
    const k = rint(2, 5), a = rint(2, 12);
    return numQ(`닮음비가 1 : ${k}인 두 도형에서 작은 도형의 한 변이 ${a}일 때 큰 도형의 대응변은?`, a * k,
      `닮음비가 1 : ${k}이므로 대응변도 ${k}배예요. ${a} × ${k} = ${a * k}\n(넓이는 ${k * k}배가 돼요)`,
      { skill: SK.shape });
  }), 8));

  units.push(makeUnit("확률", "🎲", 9, gen(40, () => {
    const t = L.rng();
    if (t < 0.4) {
      const n = rint(2, 6);
      return numQ(`주사위를 한 번 던져 ${n} 이하의 눈이 나올 확률은? (기약분수의 분자)`,
        reduce(n, 6)[0],
        `${n} 이하는 ${n}가지, 전체는 6가지예요. ${n}/6 = ${reduce(n, 6)[0]}/${reduce(n, 6)[1]}`,
        { skill: SK.data });
    }
    const r = rint(2, 8), b = rint(2, 8);
    const [rn, rd] = reduce(r, r + b);
    return numQ(`빨강 ${r}개, 파랑 ${b}개인 주머니에서 하나를 꺼낼 때 빨강일 확률은? (기약분수의 분자)`,
      rn,
      `전체 ${r + b}개 중 빨강 ${r}개예요. ${r}/${r + b} = ${rn}/${rd}`, { skill: SK.data });
  }), 8));

  return units.filter(Boolean);
}

// ================= 중3 =================
function middle3() {
  const units = [];

  units.push(makeUnit("제곱근과 실수", "√", 10, gen(45, () => {
    const n = rint(2, 20);
    if (L.rng() < 0.5) {
      return numQ(`√${n * n} 의 값은?`, n,
        `${n} × ${n} = ${n * n}이므로 √${n * n} = ${n}이에요.`, { skill: SK.number });
    }
    const a = rint(2, 9), b = rint(2, 9);
    return numQ(`√${a * a * b} = k√${b} 일 때 k는?`, a,
      `√${a * a * b} = √(${a * a} × ${b}) = ${a}√${b}\nk = ${a}예요.`, { skill: SK.number });
  }), 10));

  units.push(makeUnit("인수분해", "🧩", 10, gen(45, () => {
    const p = rint(1, 9), q = rint(1, 9);
    return textQ(
      `x² + ${p + q}x + ${p * q} 을 인수분해하면? (예: (x+2)(x+3))`,
      `(x+${p})(x+${q})`,
      `합이 ${p + q}, 곱이 ${p * q}인 두 수를 찾아요 → ${p}과 ${q}\n답: (x+${p})(x+${q})`,
      { alts: [`(x+${q})(x+${p})`], skill: SK.calc }
    );
  }), 10));

  units.push(makeUnit("이차방정식", "🟰", 10, gen(50, () => {
    const p = rint(1, 9), q = rint(1, 9);
    // (x-p)(x-q) = 0 → x² -(p+q)x + pq = 0
    return numQ(
      `x² - ${p + q}x + ${p * q} = 0 의 두 근 중 큰 값은?`,
      Math.max(p, q),
      `인수분해하면 (x-${p})(x-${q}) = 0\n근은 ${p}, ${q}이고 큰 값은 ${Math.max(p, q)}예요.`,
      { skill: SK.calc }
    );
  }), 10));

  units.push(makeUnit("이차함수", "📈", 10, gen(45, () => {
    const a = rint(1, 4), p = rint(-5, 5), q = rint(-9, 9);
    const t = L.rng();
    if (t < 0.5) {
      return numQ(`y = ${a}(x ${p >= 0 ? "- " + p : "+ " + -p})² ${q >= 0 ? "+ " + q : "- " + -q} 의 꼭짓점의 x좌표는?`,
        p,
        `y = a(x-p)² + q 꼴에서 꼭짓점은 (p, q)예요.\n꼭짓점은 (${p}, ${q})이고 x좌표는 ${p}이에요.`,
        { skill: SK.calc });
    }
    const x = rint(-4, 6);
    return numQ(`y = ${a}x² 에서 x = ${x}일 때 y는?`, a * x * x,
      `x = ${x}을 대입해요. y = ${a} × ${x}² = ${a} × ${x * x} = ${a * x * x}`, { skill: SK.calc });
  }), 10));

  units.push(makeUnit("삼각비", "📐", 10, gen(40, () => {
    const table = [
      ["sin", 30, "1/2"], ["cos", 60, "1/2"], ["tan", 45, "1"],
      ["sin", 90, "1"], ["cos", 0, "1"], ["sin", 0, "0"], ["cos", 90, "0"],
    ];
    const [f, deg, val] = pick(table);
    return textQ(`${f} ${deg}° 의 값은? (분수는 1/2 처럼)`, val,
      `특수각의 삼각비예요. ${f}${deg}° = ${val}\n30°·45°·60°의 값은 외워 두면 편해요.`,
      { skill: SK.shape });
  }), 8));

  units.push(makeUnit("원의 성질", "⭕", 10, gen(35, () => {
    const c = rint(10, 80);
    return numQ(`원에서 중심각이 ${c * 2}°인 호에 대한 원주각은? (단위 °)`, c,
      `원주각은 중심각의 절반이에요. ${c * 2}° ÷ 2 = ${c}°`, { unit: "°", skill: SK.shape });
  }), 8));

  units.push(makeUnit("통계 (대푯값)", "📊", 10, gen(35, () => {
    const n = 5;
    const vals = Array.from({ length: n }, () => rint(1, 30)).sort((a, b) => a - b);
    return numQ(`${vals.join(", ")}의 중앙값은?`, vals[2],
      `크기 순으로 늘어놓았을 때 가운데 값이 중앙값이에요. 세 번째 값 ${vals[2]}이에요.`,
      { visual: V.barGraph(vals.map((_, i) => `${i + 1}`), vals), skill: SK.data });
  }), 8));

  return units.filter(Boolean);
}

module.exports = { math_m1: middle1, math_m2: middle2, math_m3: middle3 };
