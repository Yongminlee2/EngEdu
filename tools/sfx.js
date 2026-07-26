#!/usr/bin/env node
// 효과음 합성 → WAV → (ffmpeg) → res/raw/*.ogg
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const SR = 44100;
const OUTDIR = path.join(__dirname, "..", "app", "src", "main", "res", "raw");
fs.mkdirSync(OUTDIR, { recursive: true });
const TMP = process.env.TEMP || ".";

function writeWav(file, samples) {
  const n = samples.length;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write("RIFF", 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write("WAVE", 8);
  buf.write("fmt ", 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22); buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28);
  buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write("data", 36); buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE((v * 32767) | 0, 44 + i * 2);
  }
  fs.writeFileSync(file, buf);
}

function env(t, dur, a = 0.005, r = 0.12) {
  if (t < a) return t / a;
  const rel = dur - r;
  if (t > rel) return Math.max(0, 1 - (t - rel) / r);
  return 1;
}

// 정답: 밝은 딩동 (E6 → A6)
function correct() {
  const dur = 0.45, n = (SR * dur) | 0, s = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const f = t < 0.16 ? 1318.5 : 1760;
    const seg = t < 0.16 ? t : t - 0.16;
    const segDur = t < 0.16 ? 0.16 : dur - 0.16;
    s[i] = (Math.sin(2 * Math.PI * f * t) * 0.6 + Math.sin(2 * Math.PI * f * 2 * t) * 0.15)
      * env(seg, segDur, 0.004, segDur * 0.6) * 0.7;
  }
  return s;
}

// 오답: 낮은 부저 (뚜-웅 하강)
function wrong() {
  const dur = 0.4, n = (SR * dur) | 0, s = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const f = 220 - 60 * (t / dur);
    const sq = Math.sign(Math.sin(2 * Math.PI * f * t)) * 0.25 + Math.sin(2 * Math.PI * f * t) * 0.35;
    s[i] = sq * env(t, dur, 0.008, 0.15) * 0.6;
  }
  return s;
}

// 레슨 완료: 아르페지오 팡파르 (C5-E5-G5-C6)
function done() {
  const notes = [523.25, 659.25, 783.99, 1046.5];
  const step = 0.12, tail = 0.5;
  const dur = step * 3 + tail, n = (SR * dur) | 0, s = new Float32Array(n);
  notes.forEach((f, idx) => {
    const start = idx * step;
    const ndur = idx === 3 ? tail : step * 1.8;
    for (let i = (start * SR) | 0; i < Math.min(n, ((start + ndur) * SR) | 0); i++) {
      const t = i / SR - start;
      s[i] += (Math.sin(2 * Math.PI * f * (i / SR)) * 0.5 + Math.sin(2 * Math.PI * f * 2 * (i / SR)) * 0.12)
        * env(t, ndur, 0.005, ndur * 0.5) * 0.55;
    }
  });
  return s;
}

// 삐약: 병아리 칩 2회 (주파수 스윕)
function piyak() {
  const chirp = (s, start, dur) => {
    for (let i = (start * SR) | 0; i < ((start + dur) * SR) | 0; i++) {
      const t = i / SR - start;
      const ph = t / dur;
      const f = 2800 + 900 * Math.sin(Math.PI * ph); // 위로 갔다 내려오는 스윕
      s[i] += Math.sin(2 * Math.PI * f * t) * env(t, dur, 0.004, dur * 0.4) * 0.5;
    }
  };
  const dur = 0.34, n = (SR * dur) | 0, s = new Float32Array(n);
  chirp(s, 0, 0.12);
  chirp(s, 0.17, 0.12);
  return s;
}

const sounds = { sfx_correct: correct(), sfx_wrong: wrong(), sfx_done: done(), sfx_piyak: piyak() };
const FF = "C:/ffmpeg/bin/ffmpeg.exe";
for (const [name, samples] of Object.entries(sounds)) {
  const wav = path.join(TMP, name + ".wav");
  writeWav(wav, samples);
  const ogg = path.join(OUTDIR, name + ".ogg");
  execSync(`"${FF}" -y -i "${wav}" -c:a libvorbis -q:a 3 "${ogg}"`, { stdio: "pipe" });
  console.log(name + ".ogg", fs.statSync(ogg).size, "bytes");
}
