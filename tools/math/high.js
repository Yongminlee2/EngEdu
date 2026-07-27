// 고등학교 1~3학년 수학 생성기
const L = require("./lib");
const { rint, pick, shuffled, numQ, choiceQ, textQ, V, makeUnit, gen } = L;

const SK = {
  calc: "m_calc", number: "m_number", shape: "m_shape",
  measure: "m_measure", data: "m_data", word: "m_word",
};

function fact(n) { let r = 1; for (let i = 2; i <= n; i++) r *= i; return r; }
function nPr(n, r) { let v = 1; for (let i = 0; i < r; i++) v *= n - i; return v; }
function nCr(n, r) { return nPr(n, r) / fact(r); }

// ================= 고1 =================
function high1() {
  const units = [];

  units.push(makeUnit("다항식과 나머지정리", "🧮", 11, gen(45, () => {
    const a = rint(1, 5), b = rint(-9, 9), c = rint(-9, 9), k = rint(-4, 4);
    const val = a * k * k + b * k + c;
    return numQ(
      `f(x) = ${a}x² ${b >= 0 ? "+ " + b : "- " + -b}x ${c >= 0 ? "+ " + c : "- " + -c} 를 x ${k >= 0 ? "- " + k : "+ " + -k} 로 나눈 나머지는?`,
      val,
      `나머지정리: f(x)를 (x - k)로 나눈 나머지는 f(k)예요.\nf(${k}) = ${a}×${k * k} ${b >= 0 ? "+" : "-"} ${Math.abs(b)}×${k} ${c >= 0 ? "+" : "-"} ${Math.abs(c)} = ${val}`,
      { skill: SK.calc }
    );
  }), 10));

  units.push(makeUnit("이차방정식과 판별식", "🟰", 11, gen(45, () => {
    const a = rint(1, 4), b = rint(-10, 10), c = rint(-10, 10);
    const D = b * b - 4 * a * c;
    return numQ(
      `${a}x² ${b >= 0 ? "+ " + b : "- " + -b}x ${c >= 0 ? "+ " + c : "- " + -c} = 0 의 판별식 D의 값은?`,
      D,
      `D = b² - 4ac = ${b}² - 4×${a}×${c} = ${b * b} - ${4 * a * c} = ${D}\n${D > 0 ? "D > 0 이므로 서로 다른 두 실근" : D === 0 ? "D = 0 이므로 중근" : "D < 0 이므로 실근이 없어요"}`,
      { skill: SK.calc }
    );
  }), 10));

  units.push(makeUnit("순열과 조합", "🎲", 11, gen(45, () => {
    const n = rint(4, 9), r = rint(2, Math.min(4, n - 1));
    if (L.rng() < 0.5) {
      return numQ(`서로 다른 ${n}개에서 ${r}개를 뽑아 순서대로 나열하는 경우의 수는? (${n}P${r})`,
        nPr(n, r),
        `${n}P${r} = ${Array.from({ length: r }, (_, i) => n - i).join(" × ")} = ${nPr(n, r)}`,
        { skill: SK.data });
    }
    return numQ(`서로 다른 ${n}개에서 ${r}개를 순서 없이 뽑는 경우의 수는? (${n}C${r})`,
      nCr(n, r),
      `${n}C${r} = ${n}P${r} ÷ ${r}! = ${nPr(n, r)} ÷ ${fact(r)} = ${nCr(n, r)}`,
      { skill: SK.data });
  }), 10));

  units.push(makeUnit("도형의 방정식", "📐", 11, gen(45, () => {
    const t = L.rng();
    if (t < 0.4) {
      const x1 = rint(-8, 8), y1 = rint(-8, 8), x2 = rint(-8, 8), y2 = rint(-8, 8);
      const d2 = (x2 - x1) ** 2 + (y2 - y1) ** 2;
      return numQ(`두 점 (${x1}, ${y1}), (${x2}, ${y2}) 사이 거리의 제곱은?`, d2,
        `거리² = (x₂-x₁)² + (y₂-y₁)² = ${(x2 - x1) ** 2} + ${(y2 - y1) ** 2} = ${d2}`,
        { skill: SK.shape });
    }
    const a = rint(-6, 6), b = rint(-6, 6), r = rint(1, 9);
    return numQ(`원 (x ${a >= 0 ? "- " + a : "+ " + -a})² + (y ${b >= 0 ? "- " + b : "+ " + -b})² = ${r * r} 의 반지름은?`,
      r,
      `표준형 (x-a)² + (y-b)² = r² 에서 r² = ${r * r} 이므로 반지름은 ${r}이에요. 중심은 (${a}, ${b})예요.`,
      { skill: SK.shape });
  }), 10));

  units.push(makeUnit("집합과 명제", "🔗", 11, gen(35, () => {
    const n = rint(3, 8);
    return numQ(`원소가 ${n}개인 집합의 부분집합의 개수는?`, 2 ** n,
      `부분집합의 개수 = 2ⁿ = 2^${n} = ${2 ** n}개예요.\n(진부분집합은 ${2 ** n - 1}개)`,
      { skill: SK.number });
  }), 8));

  return units.filter(Boolean);
}

// ================= 고2 (수학Ⅰ·Ⅱ) =================
function high2() {
  const units = [];

  units.push(makeUnit("지수와 로그", "🔢", 12, gen(45, () => {
    const a = pick([2, 3, 5, 10]), n = rint(2, 6);
    if (L.rng() < 0.5) {
      return numQ(`log_${a} ${a ** n} 의 값은?`, n,
        `log_${a} ${a ** n} 은 "${a}를 몇 번 곱해야 ${a ** n}이 되는가"예요. ${a}^${n} = ${a ** n} 이므로 답은 ${n}이에요.`,
        { skill: SK.calc });
    }
    return numQ(`${a}^${n} 의 값은?`, a ** n,
      `${a}를 ${n}번 곱해요. ${Array(n).fill(a).join(" × ")} = ${a ** n}`, { skill: SK.calc });
  }), 10));

  units.push(makeUnit("삼각함수", "📐", 12, gen(40, () => {
    const table = [
      ["sin", 30, "1/2"], ["sin", 90, "1"], ["sin", 180, "0"], ["sin", 0, "0"],
      ["cos", 60, "1/2"], ["cos", 0, "1"], ["cos", 180, "-1"], ["cos", 90, "0"],
      ["tan", 45, "1"], ["tan", 0, "0"], ["tan", 180, "0"],
    ];
    const [f, deg, val] = pick(table);
    return textQ(`${f} ${deg}° 의 값은?`, val,
      `단위원에서 ${deg}°의 위치를 생각해요. ${f}${deg}° = ${val}`, { skill: SK.calc });
  }), 8));

  units.push(makeUnit("수열", "📈", 12, gen(50, () => {
    const a = rint(1, 12), d = rint(1, 9), n = rint(5, 20);
    if (L.rng() < 0.5) {
      return numQ(`첫째항 ${a}, 공차 ${d}인 등차수열의 제${n}항은?`, a + (n - 1) * d,
        `aₙ = a + (n-1)d = ${a} + ${n - 1}×${d} = ${a + (n - 1) * d}`, { skill: SK.calc });
    }
    const sum = (n * (2 * a + (n - 1) * d)) / 2;
    return numQ(`첫째항 ${a}, 공차 ${d}인 등차수열의 첫 ${n}항의 합은?`, sum,
      `Sₙ = n(2a + (n-1)d)/2 = ${n}(${2 * a} + ${(n - 1) * d})/2 = ${sum}`, { skill: SK.calc });
  }), 10));

  units.push(makeUnit("함수의 극한", "➡️", 12, gen(40, () => {
    const a = rint(1, 6), b = rint(-8, 8), k = rint(-4, 4);
    return numQ(`lim(x→${k}) (${a}x ${b >= 0 ? "+ " + b : "- " + -b}) 의 값은?`, a * k + b,
      `다항함수는 연속이라 그대로 대입해요. ${a}×${k} ${b >= 0 ? "+" : "-"} ${Math.abs(b)} = ${a * k + b}`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("미분", "📉", 12, gen(50, () => {
    const a = rint(1, 6), b = rint(1, 9), c = rint(-9, 9), x = rint(-4, 5);
    // f(x) = ax³ + bx² + c → f'(x) = 3ax² + 2bx
    const d = 3 * a * x * x + 2 * b * x;
    return numQ(
      `f(x) = ${a}x³ + ${b}x² ${c >= 0 ? "+ " + c : "- " + -c} 일 때 f'(${x})의 값은?`,
      d,
      `f'(x) = ${3 * a}x² + ${2 * b}x\nf'(${x}) = ${3 * a}×${x * x} + ${2 * b}×${x} = ${3 * a * x * x} + ${2 * b * x} = ${d}`,
      { skill: SK.calc }
    );
  }), 10));

  units.push(makeUnit("적분", "📐", 12, gen(45, () => {
    const a = rint(1, 6), n = rint(1, 4), up = rint(1, 5);
    // ∫₀^up a x^n dx = a * up^(n+1) / (n+1)
    const val = (a * up ** (n + 1)) / (n + 1);
    return numQ(
      `∫₀^${up} ${a}x^${n} dx 의 값은?`,
      Math.round(val * 1000) / 1000,
      `부정적분은 ${a}x^${n + 1}/${n + 1} 이에요.\n${up}을 대입: ${a}×${up ** (n + 1)}/${n + 1} = ${Math.round(val * 1000) / 1000}`,
      { skill: SK.calc }
    );
  }), 10));

  return units.filter(Boolean);
}

// ================= 고3 (미적분·확통·기하) =================
function high3() {
  const units = [];

  units.push(makeUnit("수열의 극한", "➡️", 13, gen(40, () => {
    const a = rint(1, 9), b = rint(1, 9);
    return numQ(`lim(n→∞) (${a}n + 5)/(${b}n + 2) 의 값은? (소수 셋째 자리까지)`,
      Math.round((a / b) * 1000) / 1000,
      `분자·분모를 n으로 나눠요. (${a} + 5/n)/(${b} + 2/n) → ${a}/${b} = ${Math.round((a / b) * 1000) / 1000}\n최고차항의 계수 비가 답이에요.`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("여러 가지 함수의 미분", "📉", 13, gen(45, () => {
    const a = rint(2, 8), x = rint(1, 5);
    const t = L.rng();
    if (t < 0.5) {
      return numQ(`f(x) = ${a}x⁴ 일 때 f'(${x})의 값은?`, 4 * a * x ** 3,
        `f'(x) = ${4 * a}x³\nf'(${x}) = ${4 * a} × ${x ** 3} = ${4 * a * x ** 3}`, { skill: SK.calc });
    }
    return numQ(`f(x) = ${a}x² 일 때 x = ${x} 에서의 접선의 기울기는?`, 2 * a * x,
      `접선의 기울기는 f'(${x})예요. f'(x) = ${2 * a}x 이므로 ${2 * a}×${x} = ${2 * a * x}`,
      { skill: SK.calc });
  }), 10));

  units.push(makeUnit("정적분과 넓이", "📐", 13, gen(40, () => {
    const a = rint(1, 5), up = rint(2, 6);
    const val = (a * up ** 3) / 3;
    return numQ(`곡선 y = ${a}x² 과 x축, x = ${up} 로 둘러싸인 부분의 넓이는? (소수 셋째 자리까지)`,
      Math.round(val * 1000) / 1000,
      `넓이 = ∫₀^${up} ${a}x² dx = ${a}x³/3 을 ${up}에 대입 = ${a}×${up ** 3}/3 = ${Math.round(val * 1000) / 1000}`,
      { skill: SK.measure });
  }), 10));

  units.push(makeUnit("확률과 통계", "🎲", 13, gen(45, () => {
    const t = L.rng();
    if (t < 0.4) {
      const n = rint(4, 9), r = rint(2, 4);
      return numQ(`${n}명 중 ${r}명을 뽑는 방법의 수는?`, nCr(n, r),
        `${n}C${r} = ${nPr(n, r)} ÷ ${fact(r)} = ${nCr(n, r)}가지`, { skill: SK.data });
    }
    const n = rint(2, 5), p = pick([2, 4, 5]);
    // 독립시행: 확률 1/p 인 사건이 n번 모두 일어날 확률의 분모
    return numQ(`확률이 1/${p}인 일이 ${n}번 연속으로 일어날 확률은 1/k 일 때 k는?`, p ** n,
      `독립시행이므로 곱해요. (1/${p})^${n} = 1/${p ** n}\nk = ${p ** n}`, { skill: SK.data });
  }), 10));

  units.push(makeUnit("공간도형과 벡터", "🧊", 13, gen(40, () => {
    const t = L.rng();
    if (t < 0.5) {
      const x = rint(-6, 6), y = rint(-6, 6), z = rint(-6, 6);
      return numQ(`점 (${x}, ${y}, ${z}) 와 원점 사이 거리의 제곱은?`, x * x + y * y + z * z,
        `거리² = x² + y² + z² = ${x * x} + ${y * y} + ${z * z} = ${x * x + y * y + z * z}`,
        { skill: SK.shape });
    }
    const a1 = rint(-5, 5), a2 = rint(-5, 5), b1 = rint(-5, 5), b2 = rint(-5, 5);
    return numQ(`두 벡터 (${a1}, ${a2}) 와 (${b1}, ${b2}) 의 내적은?`, a1 * b1 + a2 * b2,
      `내적 = x₁x₂ + y₁y₂ = ${a1}×${b1} + ${a2}×${b2} = ${a1 * b1} + ${a2 * b2} = ${a1 * b1 + a2 * b2}`,
      { skill: SK.shape });
  }), 10));

  units.push(makeUnit("이차곡선", "⭕", 13, gen(35, () => {
    const a = rint(2, 8), b = rint(1, 6);
    return numQ(`타원 x²/${a * a} + y²/${b * b} = 1 의 장축의 길이는?`, 2 * a,
      `x²/a² + y²/b² = 1 에서 a = ${a}, b = ${b}\n장축의 길이는 2a = ${2 * a}예요.`,
      { skill: SK.shape });
  }), 8));

  return units.filter(Boolean);
}

module.exports = { math_h1: high1, math_h2: high2, math_h3: high3 };
