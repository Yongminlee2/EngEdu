// 문장제 생성기 — 학년별로 상황을 바꿔 가며 낸다.
// 실력 대시보드의 "🧩 문장제" 영역을 채우는 문제들이다.
const L = require("./lib");
const { rint, pick, numQ, V, makeUnit, gen } = L;

const SK_WORD = "m_word";

const NAMES = ["민수", "지우", "서연", "하준", "예린", "도윤", "수아", "시우", "채원", "은우"];
const ITEMS = [
  { n: "사탕", e: "🍬" }, { n: "구슬", e: "🔵" }, { n: "딸기", e: "🍓" },
  { n: "색연필", e: "✏️" }, { n: "스티커", e: "⭐" }, { n: "쿠키", e: "🍪" },
  { n: "풍선", e: "🎈" }, { n: "블록", e: "🧱" }, { n: "귤", e: "🍊" },
];
const PLACES = ["바구니", "상자", "봉지", "접시", "가방"];

/** 초1~2: 덧셈·뺄셈 문장제 (그림 포함) */
function wordAddSub(level, maxN) {
  return gen(40, () => {
    const who = pick(NAMES);
    const it = pick(ITEMS);
    const a = rint(2, maxN);
    const b = rint(1, Math.max(1, Math.min(maxN, a)));
    if (L.rng() < 0.55) {
      return numQ(
        `${who}이(가) ${it.n}을 ${a}개 가지고 있어요.\n친구에게 ${b}개를 더 받았어요.\n${it.n}은 모두 몇 개일까요?`,
        a + b,
        `더 받았으니 덧셈이에요.\n${a} + ${b} = ${a + b}개`,
        { visual: V.emojiOp(it.e, Math.min(a, 8), Math.min(b, 8), "+"), unit: "개", skill: SK_WORD }
      );
    }
    return numQ(
      `${who}이(가) ${it.n}을 ${a}개 가지고 있어요.\n그중 ${b}개를 동생에게 주었어요.\n남은 ${it.n}은 몇 개일까요?`,
      a - b,
      `주었으니 뺄셈이에요.\n${a} - ${b} = ${a - b}개`,
      { visual: V.emojiOp(it.e, Math.min(a, 8), Math.min(b, 8), "-"), unit: "개", skill: SK_WORD }
    );
  });
}

/** 초2~3: 곱셈·나눗셈 문장제 */
function wordMulDiv(level) {
  return gen(40, () => {
    const who = pick(NAMES);
    const it = pick(ITEMS);
    const place = pick(PLACES);
    const per = rint(2, 9);
    const cnt = rint(2, 9);
    if (L.rng() < 0.5) {
      return numQ(
        `${place} 한 개에 ${it.n}이 ${per}개씩 들어 있어요.\n${place}가 ${cnt}개 있으면 ${it.n}은 모두 몇 개일까요?`,
        per * cnt,
        `${per}개씩 ${cnt}묶음이니까 곱셈이에요.\n${per} × ${cnt} = ${per * cnt}개`,
        { visual: V.array(it.e, cnt, per), unit: "개", skill: SK_WORD }
      );
    }
    const total = per * cnt;
    return numQ(
      `${who}이(가) ${it.n} ${total}개를 ${cnt}명에게 똑같이 나누어 주려고 해요.\n한 명이 몇 개씩 받을까요?`,
      per,
      `똑같이 나누니까 나눗셈이에요.\n${total} ÷ ${cnt} = ${per}개\n확인: ${cnt} × ${per} = ${total}`,
      { visual: V.array(it.e, cnt, per), unit: "개", skill: SK_WORD }
    );
  });
}

/** 초4~5: 두 단계 계산 문장제 */
function wordTwoStep() {
  return gen(40, () => {
    const who = pick(NAMES);
    const it = pick(ITEMS);
    const per = rint(3, 12);
    const cnt = rint(3, 12);
    const used = rint(2, per * cnt - 1);
    return numQ(
      `${who}이(가) ${it.n}을 한 상자에 ${per}개씩 ${cnt}상자 샀어요.\n그중 ${used}개를 나누어 주었다면 남은 것은 몇 개일까요?`,
      per * cnt - used,
      `먼저 전체를 구해요. ${per} × ${cnt} = ${per * cnt}개\n나누어 준 것을 빼요. ${per * cnt} - ${used} = ${per * cnt - used}개`,
      { unit: "개", skill: SK_WORD }
    );
  });
}

/** 초5~6: 평균·비율 문장제 */
function wordAverageRatio() {
  return gen(40, () => {
    if (L.rng() < 0.5) {
      const n = rint(3, 5);
      const avg = rint(60, 95);
      const vals = [];
      let rest = avg * n;
      for (let i = 0; i < n - 1; i++) {
        const v = rint(50, 100);
        vals.push(v);
        rest -= v;
      }
      if (rest < 0 || rest > 100) return null;
      vals.push(rest);
      return numQ(
        `시험 점수가 ${vals.slice(0, n - 1).join(", ")}점이고 마지막 점수가 ${rest}점이에요.\n평균은 몇 점일까요?`,
        avg,
        `모두 더하면 ${vals.reduce((s, v) => s + v, 0)}점이에요.\n과목이 ${n}개니까 ${vals.reduce((s, v) => s + v, 0)} ÷ ${n} = ${avg}점`,
        { visual: V.barGraph(vals.map((_, i) => `${i + 1}`), vals), unit: "점", skill: SK_WORD }
      );
    }
    const total = rint(2, 20) * 10;
    const pct = rint(1, 9) * 10;
    return numQ(
      `전체 ${total}명 중 ${pct}%가 안경을 썼어요.\n안경을 쓴 사람은 몇 명일까요?`,
      (total * pct) / 100,
      `${pct}% = ${pct}/100 이에요.\n${total} × ${pct} ÷ 100 = ${(total * pct) / 100}명`,
      { unit: "명", skill: SK_WORD }
    );
  });
}

/** 중등: 방정식 문장제 */
function wordEquation() {
  return gen(40, () => {
    const who = pick(NAMES);
    const t = L.rng();
    if (t < 0.4) {
      const x = rint(3, 30);
      const a = rint(2, 6), b = rint(1, 20);
      return numQ(
        `어떤 수에 ${a}를 곱하고 ${b}를 더했더니 ${a * x + b}이 되었어요.\n어떤 수는 얼마일까요?`,
        x,
        `어떤 수를 x라 하면 ${a}x + ${b} = ${a * x + b}\n${a}x = ${a * x}\nx = ${x}`,
        { skill: SK_WORD }
      );
    }
    if (t < 0.7) {
      const apple = rint(2, 9), pear = rint(2, 9);
      const na = rint(2, 8), np = rint(2, 8);
      return numQ(
        `사과 한 개는 ${apple}00원, 배 한 개는 ${pear}00원이에요.\n사과 ${na}개와 배 ${np}개를 사면 모두 얼마일까요?`,
        (apple * na + pear * np) * 100,
        `사과: ${apple}00 × ${na} = ${apple * na * 100}원\n배: ${pear}00 × ${np} = ${pear * np * 100}원\n합: ${(apple * na + pear * np) * 100}원`,
        { unit: "원", skill: SK_WORD }
      );
    }
    const speed = rint(3, 12), time = rint(2, 9);
    return numQ(
      `${who}이(가) 시속 ${speed}km로 ${time}시간 동안 걸었어요.\n몇 km를 갔을까요?`,
      speed * time,
      `거리 = 속력 × 시간\n${speed} × ${time} = ${speed * time}km`,
      { unit: "km", skill: SK_WORD }
    );
  });
}

module.exports = {
  unitFor(gradeId, level) {
    switch (gradeId) {
      case "math_g1":
        return makeUnit("이야기 문제 (더하기·빼기)", "🧩", level, wordAddSub(level, 9), 8);
      case "math_g2":
        return makeUnit("이야기 문제 (더하기·빼기)", "🧩", level, wordAddSub(level, 40), 8);
      case "math_g3":
        return makeUnit("이야기 문제 (곱하기·나누기)", "🧩", level, wordMulDiv(level), 8);
      case "math_g4":
        return makeUnit("이야기 문제 (두 단계)", "🧩", level, wordTwoStep(), 8);
      case "math_g5":
        return makeUnit("이야기 문제 (평균·비율)", "🧩", level, wordAverageRatio(), 8);
      case "math_g6":
        return makeUnit("이야기 문제 (비율·속력)", "🧩", level, wordEquation(), 8);
      case "math_m1":
      case "math_m2":
        return makeUnit("방정식 문장제", "🧩", level, wordEquation(), 10);
      default:
        return null;
    }
  },
};
