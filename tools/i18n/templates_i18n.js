/**
 * 문제문·해설 **뼈대** 번역의 모음집.
 *
 * 실제 번역은 tpl/ 폴더 안에 묶음별로 나눠 놓았다 (한 파일이 너무 커지지 않게).
 * 파일을 새로 넣으면 자동으로 합쳐진다 — 여기는 손댈 일이 없다.
 *
 * 같은 키가 두 파일에 있으면 나중 파일이 이긴다.
 */
const fs = require("fs");
const path = require("path");

const DIR = path.join(__dirname, "tpl");
const out = {};
for (const f of fs.readdirSync(DIR).sort()) {
  if (!f.endsWith(".js")) continue;
  Object.assign(out, require(path.join(DIR, f)));
}
module.exports = out;
