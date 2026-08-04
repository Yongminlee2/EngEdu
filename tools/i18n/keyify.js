/**
 * 문제 생성기의 **문제문**에 번역 키를 심는다.
 *
 *   node tools/i18n/keyify.js          # 미리보기
 *   node tools/i18n/keyify.js --write  # 실제로 고침
 *
 * 문제를 만드는 함수마다 문제문 자리가 다르므로(PROMPT_SLOT) 그 자리만 골라
 *
 *     `"${w}" 의 뜻은?`
 *   → tp("3f2a91c7", [w], `"${w}" 의 뜻은?`)
 *
 * 이렇게 감싼다. **한국어 원문이 그대로 남으므로 한국어 동작은 1도 안 변한다.**
 * 키는 뼈대 문장의 해시라 같은 문장은 늘 같은 키가 되고, 몇 번을 돌려도 같다.
 *
 * 보기·정답·해설은 건드리지 않는다 — 그건 낱말 뜻이라 다른 방식으로 다룬다.
 */
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const DIR = path.join(__dirname, "..");
const FILES = ["gen.js", "gen_elem_english.js"];

/**
 * 파일마다 같은 이름의 빌더가 **인자 순서가 다르다.**
 *   gen.js              : mcq(prefix, prompt, …)  listenMcq(prefix, tts, prompt, …)
 *   gen_elem_english.js : mcq(prompt, …)          listenMcq(tts, prompt, …)
 */
const PROMPT_SLOT_BY_FILE = {
  "gen.js": { mcq: 1, listenMcq: 2 },
  "gen_elem_english.js": { mcq: 0, listenMcq: 1 },
};

const BT = String.fromCharCode(96);
const WRITE = process.argv.includes("--write");

// ---------- 소스 훑기 (따옴표·템플릿·주석을 건너뛴다) ----------
function skipQuote(s, i) {
  const q = s[i]; i++;
  while (i < s.length) {
    if (s[i] === "\\") { i += 2; continue; }
    if (s[i] === q) return i + 1;
    i++;
  }
  return i;
}
function skipTemplate(s, i) {
  i++;
  while (i < s.length) {
    if (s[i] === "\\") { i += 2; continue; }
    if (s[i] === BT) return i + 1;
    if (s[i] === "$" && s[i + 1] === "{") { i = skipExpr(s, i + 2); continue; }
    i++;
  }
  return i;
}
/** ${ 다음부터 짝이 맞는 } 다음 위치까지 */
function skipExpr(s, i) {
  let d = 1;
  while (i < s.length && d > 0) {
    const c = s[i];
    if (c === "\\") { i += 2; continue; }
    if (c === '"' || c === "'") { i = skipQuote(s, i); continue; }
    if (c === BT) { i = skipTemplate(s, i); continue; }
    if (c === "{") d++;
    if (c === "}") d--;
    i++;
  }
  return i;
}
/** 여는 괄호 위치를 주면 인자마다 [시작, 끝) 을 돌려준다 */
function splitArgs(s, open) {
  const args = [];
  let depth = 0, i = open + 1, start = i;
  while (i < s.length) {
    const c = s[i];
    if (c === "\\") { i += 2; continue; }
    if (c === '"' || c === "'") { i = skipQuote(s, i); continue; }
    if (c === BT) { i = skipTemplate(s, i); continue; }
    if (c === "/" && s[i + 1] === "/") { while (i < s.length && s[i] !== "\n") i++; continue; }
    if (c === "/" && s[i + 1] === "*") { i = s.indexOf("*/", i) + 2; continue; }
    if (c === "(" || c === "[" || c === "{") { depth++; i++; continue; }
    if (c === ")" && depth === 0) { args.push([start, i]); return { args, end: i }; }
    if (c === ")" || c === "]" || c === "}") { depth--; i++; continue; }
    if (c === "," && depth === 0) { args.push([start, i]); start = i + 1; i++; continue; }
    i++;
  }
  return null;   // 괄호가 안 닫혔다 = 우리가 찾던 호출이 아니다
}

// ---------- 템플릿 → 뼈대 + 인자식 ----------
function toSkeleton(src) {
  const isTpl = src[0] === BT;
  const body = src.slice(1, -1);
  let out = "", i = 0;
  const exprs = [];
  while (i < body.length) {
    const c = body[i];
    if (c === "\\") { out += body.substr(i, 2); i += 2; continue; }
    if (isTpl && c === "$" && body[i + 1] === "{") {
      const st = i + 2;
      const end = skipExpr(body, st);
      exprs.push(body.slice(st, end - 1).trim());
      out += "%" + exprs.length + "$s";
      i = end; continue;
    }
    if (c === "%") { out += "%%"; i++; continue; }   // 안드로이드 서식문자 회피
    out += c; i++;
  }
  return { skeleton: out, exprs };
}
const keyOf = (skel) => crypto.createHash("sha1").update(skel).digest("hex").slice(0, 8);

// ---------- 본작업 ----------
const manifest = {};
let nWrapped = 0, nSkipped = 0;

for (const f of FILES) {
  const p = path.join(DIR, f);
  if (!fs.existsSync(p)) continue;
  let src = fs.readFileSync(p, "utf8");
  const edits = [];
  const PROMPT_SLOT = PROMPT_SLOT_BY_FILE[f] || {};

  /**
   * 이 위치의 템플릿이 **이미 tp(...) 안에 있는지** — 우리가 감싼 모양 그대로를 본다.
   * 이 검사가 없으면 두 번째 실행에서 tp(tp(...)) 로 이중 포장된다 (실제로 났던 사고).
   */
  const alreadyWrapped = (i) =>
    /tp\("[0-9a-f]{8}",\s*\[[^\]]*\],\s*$/.test(src.slice(Math.max(0, i - 120), i));

  const call = new RegExp("\\b(" + Object.keys(PROMPT_SLOT).join("|") + ")\\s*\\(", "g");
  let m;
  while ((m = call.exec(src))) {
    // 함수 정의(function mcq(...))는 건너뛴다
    if (/function\s+$/.test(src.slice(Math.max(0, m.index - 12), m.index))) continue;
    const open = m.index + m[0].length - 1;
    const parsed = splitArgs(src, open);
    if (!parsed) continue;
    call.lastIndex = parsed.end;

    const range = parsed.args[PROMPT_SLOT[m[1]]];
    if (!range) continue;
    let [a, b] = range;
    while (a < b && /\s/.test(src[a])) a++;
    while (b > a && /\s/.test(src[b - 1])) b--;
    const text = src.slice(a, b);
    if (!text || text.startsWith("tp(")) continue;      // 이미 처리됨

    const q = text[0];
    if (q !== BT && q !== '"' && q !== "'") { nSkipped++; continue; }   // 통짜 문장이 아님
    const close = q === BT ? skipTemplate(src, a) : skipQuote(src, a);
    if (close !== b) { nSkipped++; continue; }

    const { skeleton, exprs } = toSkeleton(text);
    if (!/[가-힣]/.test(skeleton)) continue;             // 번역할 한글이 없다

    const key = keyOf(skeleton);
    if (manifest[key]) manifest[key].n++;
    else manifest[key] = { ko: skeleton, args: exprs.length, n: 1 };

    edits.push([a, b, `tp("${key}", [${exprs.join(", ")}], ${text})`]);
    nWrapped++;
  }

  // ---- 객체 리터럴의 prompt: 필드 ----
  // listen_dialog 처럼 빌더 없이 validate({ prompt: `...` }) 로 만드는 문제용.
  // 감싼 뒤에는 필드값이 tp( 로 시작하므로(백틱이 아님) 자연히 다시 안 잡힌다.
  const pf = /\bprompt:\s*/g;
  let pm;
  while ((pm = pf.exec(src))) {
    const a0 = pm.index + pm[0].length;
    if (src[a0] !== BT) continue;
    const end = skipTemplate(src, a0);
    const text = src.slice(a0, end);
    if (!/[가-힣]/.test(text)) { pf.lastIndex = end; continue; }
    const { skeleton, exprs } = toSkeleton(text);
    const key = keyOf(skeleton);
    if (manifest[key]) manifest[key].n++;
    else manifest[key] = { ko: skeleton, args: exprs.length, n: 1 };
    edits.push([a0, end, `tp("${key}", [${exprs.join(", ")}], ${text})`]);
    nWrapped++;
    pf.lastIndex = end;
  }

  // ---- 문제문 모음 배열도 훑는다 ----
  // 대부분의 문제문은 `scenePick(key, SCENE_MEAN)(w)` 처럼 **배열에 담긴 화살표 함수**라
  // 호출 자리에서는 안 보인다. SCENE_* / PROMPT_* 배열 안의 템플릿을 직접 감싼다.
  const arr = /const\s+((?:SCENE|PROMPT)_\w+)\s*=\s*\[/g;
  let am;
  while ((am = arr.exec(src))) {
    const open = am.index + am[0].length - 1;
    let i = open + 1, depth = 1;
    while (i < src.length && depth > 0) {
      const c = src[i];
      if (c === "\\") { i += 2; continue; }
      if (c === '"' || c === "'") { i = skipQuote(src, i); continue; }
      if (c === BT) {
        const end = skipTemplate(src, i);
        const text = src.slice(i, end);
        if (/[가-힣]/.test(text) && !alreadyWrapped(i)) {
          const { skeleton, exprs } = toSkeleton(text);
          const key = keyOf(skeleton);
          if (manifest[key]) manifest[key].n++;
          else manifest[key] = { ko: skeleton, args: exprs.length, n: 1 };
          edits.push([i, end, `tp("${key}", [${exprs.join(", ")}], ${text})`]);
          nWrapped++;
        }
        i = end; continue;
      }
      if (c === "[") depth++;
      if (c === "]") depth--;
      i++;
    }
    arr.lastIndex = i;
  }

  if (!edits.length) continue;
  edits.sort((x, y) => y[0] - x[0]);   // 뒤에서부터 고쳐야 위치가 안 밀린다
  for (const [a, b, t] of edits) src = src.slice(0, a) + t + src.slice(b);
  console.log(`${f}: ${edits.length}곳`);
  if (WRITE) fs.writeFileSync(p, src, "utf8");
}

console.log(`\n감싼 문제문 ${nWrapped}곳 / 뼈대 ${Object.keys(manifest).length}종 · 통짜가 아니라 건너뜀 ${nSkipped}곳`);
if (WRITE) {
  // 이전 실행에서 이미 감싼 뼈대는 이번 manifest 에 없다 —
  // 기존 파일과 **합쳐서** 저장해야 목록이 줄어들지 않는다.
  const out = path.join(__dirname, "templates.json");
  const prev = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")) : {};
  fs.writeFileSync(out, JSON.stringify({ ...prev, ...manifest }, null, 1), "utf8");
  console.log(`→ templates.json 저장 (기존 ${Object.keys(prev).length} + 신규 ${Object.keys(manifest).length})`);
} else {
  console.log("(미리보기입니다. 실제로 고치려면 --write)");
}
