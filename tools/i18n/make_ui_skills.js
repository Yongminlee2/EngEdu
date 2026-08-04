/**
 * 수학 앱(ui_data.js)에서 한국어 원문이 같은 실력·칭호·배지 키를 그대로 베껴 와
 * ui_skills.js 를 만든다. 영어 앱에만 있는 키는 아래 EXTRA 에 직접 쓴다.
 *
 *   node tools/i18n/make_ui_skills.js   (한 번 만들면 끝 — 재실행하면 다시 만든다)
 */
const fs = require("fs");
const path = require("path");

const MATH = "C:/workAndroid/PiyakMath/tools/i18n/ui_data.js";

// 한국어 원문이 두 앱에서 동일한 키 (베껴 오기 전에 ko 를 검증한다)
const COPY = {
  sk_calc: "계산", sk_number: "수 감각", sk_shape: "도형", sk_measure: "측정",
  sk_data: "자료와 확률", sk_word: "문장제",
  rk_seed: "알 속의 새싹", rk_hatch: "갓 깬 병아리", rk_piyak: "삐약이",
  rk_brave: "씩씩한 병아리", rk_sparrow: "재잘재잘 참새", rk_dove: "자유로운 비둘기",
  rk_parrot: "수다쟁이 앵무새", rk_owl: "지혜로운 부엉이", rk_eagle: "하늘의 독수리",
  bg_first_lesson: "첫걸음", bg_first_lesson_d: "첫 레슨 완료",
  bg_lessons_10: "공부벌레", bg_lessons_10_d: "레슨 10개 완료",
  bg_lessons_50: "모범생", bg_lessons_50_d: "레슨 50개 완료",
  bg_lessons_200_d: "레슨 200개 완료",
  bg_perfect_10: "완벽주의", bg_perfect_10_d: "퍼펙트 레슨 10회",
  bg_streak_7: "일주일 불꽃", bg_streak_7_d: "7일 연속 학습",
  bg_streak_30: "한달 화산", bg_streak_30_d: "30일 연속 학습",
  bg_xp_1000: "별 헤는 밤", bg_xp_1000_d: "누적 XP 1,000",
  bg_xp_5000: "슈퍼스타", bg_xp_5000_d: "누적 XP 5,000",
  bg_placement: "제자리 찾기", bg_placement_d: "레벨테스트 완료",
  bg_review_50: "오답 청소부", bg_review_50_d: "오답 50개 클리어",
  bg_unit_master: "유닛 정복자", bg_unit_master_d: "한 트랙의 유닛 5개 완료",
  bg_goal_first: "목표 달성", bg_goal_first_d: "오늘의 목표 첫 달성",
  bg_goal_10: "목표 사냥꾼", bg_goal_10_d: "일일 목표 10번 달성",
  bg_m_calc: "계산왕", bg_m_shape: "도형 박사", bg_m_word: "문장제 해결사",
  bg_m_all: "수학 만능",
};

// 영어 앱 전용 (수학과 원문이 다르거나 수학에 없는 키)
const EXTRA = `
// ---------- 영어 실력 영역 ----------
sk_listen: { ko:"듣기", en:"Listening", ja:"リスニング", zh:"听力", es:"Escucha", fr:"Écoute", de:"Hören", pt:"Escuta", ru:"Аудирование", vi:"Nghe", th:"การฟัง", in:"Menyimak" },
sk_speak: { ko:"말하기", en:"Speaking", ja:"スピーキング", zh:"口语", es:"Habla", fr:"Expression orale", de:"Sprechen", pt:"Fala", ru:"Говорение", vi:"Nói", th:"การพูด", in:"Berbicara" },
sk_write: { ko:"쓰기", en:"Writing", ja:"ライティング", zh:"写作", es:"Escritura", fr:"Écriture", de:"Schreiben", pt:"Escrita", ru:"Письмо", vi:"Viết", th:"การเขียน", in:"Menulis" },
sk_grammar: { ko:"문법", en:"Grammar", ja:"ぶんぽう", zh:"语法", es:"Gramática", fr:"Grammaire", de:"Grammatik", pt:"Gramática", ru:"Грамматика", vi:"Ngữ pháp", th:"ไวยากรณ์", in:"Tata bahasa" },
sk_read: { ko:"독해", en:"Reading", ja:"どっかい", zh:"阅读", es:"Lectura", fr:"Lecture", de:"Lesen", pt:"Leitura", ru:"Чтение", vi:"Đọc hiểu", th:"การอ่าน", in:"Membaca" },
sk_vocab: { ko:"어휘", en:"Vocabulary", ja:"ごい", zh:"词汇", es:"Vocabulario", fr:"Vocabulaire", de:"Wortschatz", pt:"Vocabulário", ru:"Словарный запас", vi:"Từ vựng", th:"คำศัพท์", in:"Kosakata" },

// ---------- 칭호 (마지막 하나만 수학과 다르다) ----------
rk_master: { ko:"영어 마스터", en:"English master", ja:"えいごマスター", zh:"英语大师", es:"Maestro del inglés", fr:"Maître d'anglais", de:"Englisch-Meister", pt:"Mestre do inglês", ru:"Мастер английского", vi:"Bậc thầy tiếng Anh", th:"ยอดฝีมือภาษาอังกฤษ", in:"Master bahasa Inggris" },

// ---------- 영어 전용 배지 ----------
bg_lessons_200: { ko:"영어왕", en:"English king", ja:"えいごおう", zh:"英语王", es:"Rey del inglés", fr:"Roi de l'anglais", de:"Englisch-König", pt:"Rei do inglês", ru:"Король английского", vi:"Vua tiếng Anh", th:"ราชาภาษาอังกฤษ", in:"Raja bahasa Inggris" },
bg_ear: { ko:"귀가 트였다", en:"Open ears", ja:"みみが ひらいた", zh:"耳朵开窍了", es:"Oído despierto", fr:"Oreille affûtée", de:"Offene Ohren", pt:"Ouvido apurado", ru:"Слух открылся", vi:"Tai đã thông", th:"หูเปิดแล้ว", in:"Telinga terbuka" },
bg_ear_d: { ko:"듣기 실력 Lv.5", en:"Listening skill Lv.5", ja:"リスニング Lv.5", zh:"听力 Lv.5", es:"Escucha Lv.5", fr:"Écoute niv.5", de:"Hören Lv.5", pt:"Escuta Lv.5", ru:"Аудирование ур.5", vi:"Kỹ năng nghe Lv.5", th:"ทักษะการฟัง Lv.5", in:"Menyimak Lv.5" },
bg_mouth: { ko:"입이 트였다", en:"Talking freely", ja:"くちが ひらいた", zh:"嘴巴开窍了", es:"Lengua suelta", fr:"Langue déliée", de:"Redefluss", pt:"Língua solta", ru:"Речь пошла", vi:"Miệng đã thông", th:"พูดคล่องแล้ว", in:"Lancar bicara" },
bg_mouth_d: { ko:"말하기 실력 Lv.5", en:"Speaking skill Lv.5", ja:"スピーキング Lv.5", zh:"口语 Lv.5", es:"Habla Lv.5", fr:"Expression orale niv.5", de:"Sprechen Lv.5", pt:"Fala Lv.5", ru:"Говорение ур.5", vi:"Kỹ năng nói Lv.5", th:"ทักษะการพูด Lv.5", in:"Berbicara Lv.5" },
bg_hand: { ko:"손이 풀렸다", en:"Nimble hands", ja:"てが すらすら", zh:"手感来了", es:"Manos sueltas", fr:"Main déliée", de:"Lockere Hand", pt:"Mão solta", ru:"Рука расписалась", vi:"Tay đã quen", th:"มือคล่องแล้ว", in:"Tangan lentur" },
bg_hand_d: { ko:"쓰기 실력 Lv.5", en:"Writing skill Lv.5", ja:"ライティング Lv.5", zh:"写作 Lv.5", es:"Escritura Lv.5", fr:"Écriture niv.5", de:"Schreiben Lv.5", pt:"Escrita Lv.5", ru:"Письмо ур.5", vi:"Kỹ năng viết Lv.5", th:"ทักษะการเขียน Lv.5", in:"Menulis Lv.5" },
bg_grammar: { ko:"문법 도사", en:"Grammar guru", ja:"ぶんぽうの たつじん", zh:"语法高手", es:"Gurú de la gramática", fr:"As de la grammaire", de:"Grammatik-Guru", pt:"Guru da gramática", ru:"Гуру грамматики", vi:"Cao thủ ngữ pháp", th:"เซียนไวยากรณ์", in:"Ahli tata bahasa" },
bg_grammar_d: { ko:"문법 실력 Lv.5", en:"Grammar skill Lv.5", ja:"ぶんぽう Lv.5", zh:"语法 Lv.5", es:"Gramática Lv.5", fr:"Grammaire niv.5", de:"Grammatik Lv.5", pt:"Gramática Lv.5", ru:"Грамматика ур.5", vi:"Ngữ pháp Lv.5", th:"ไวยากรณ์ Lv.5", in:"Tata bahasa Lv.5" },
bg_all: { ko:"만능 삐약이", en:"All-round chick", ja:"オールマイティ ぴよ", zh:"全能小鸡", es:"Pollito todoterreno", fr:"Poussin complet", de:"Allround-Küken", pt:"Pintinho completo", ru:"Цыплёнок-универсал", vi:"Gà con toàn năng", th:"ลูกเจี๊ยบรอบด้าน", in:"Anak ayam serba bisa" },
bg_all_d: { ko:"영어 모든 영역 Lv.3 이상", en:"All English skills Lv.3+", ja:"えいご ぜんいき Lv.3 いじょう", zh:"英语所有领域 Lv.3 以上", es:"Todas las áreas de inglés Lv.3+", fr:"Toutes les compétences d'anglais niv.3+", de:"Alle Englisch-Bereiche Lv.3+", pt:"Todas as áreas de inglês Lv.3+", ru:"Все области английского ур.3+", vi:"Mọi kỹ năng tiếng Anh Lv.3+", th:"ทุกด้านภาษาอังกฤษ Lv.3 ขึ้นไป", in:"Semua area Inggris Lv.3+" },

// ---------- 수학 배지 설명 (영어 앱은 '수학' 접두어가 붙는다) ----------
bg_m_calc_d: { ko:"수학 계산 실력 Lv.5", en:"Math calculation Lv.5", ja:"さんすうの けいさん Lv.5", zh:"数学计算 Lv.5", es:"Cálculo (mates) Lv.5", fr:"Calcul (maths) niv.5", de:"Mathe-Rechnen Lv.5", pt:"Cálculo (mat.) Lv.5", ru:"Матем. вычисления ур.5", vi:"Tính toán (toán) Lv.5", th:"การคำนวณ (คณิต) Lv.5", in:"Berhitung (mtk) Lv.5" },
bg_m_shape_d: { ko:"수학 도형 실력 Lv.5", en:"Math shapes Lv.5", ja:"さんすうの ずけい Lv.5", zh:"数学图形 Lv.5", es:"Figuras (mates) Lv.5", fr:"Figures (maths) niv.5", de:"Mathe-Formen Lv.5", pt:"Figuras (mat.) Lv.5", ru:"Матем. фигуры ур.5", vi:"Hình học (toán) Lv.5", th:"รูปทรง (คณิต) Lv.5", in:"Bangun (mtk) Lv.5" },
bg_m_word_d: { ko:"수학 문장제 실력 Lv.5", en:"Math word problems Lv.5", ja:"さんすうの ぶんしょうだい Lv.5", zh:"数学应用题 Lv.5", es:"Problemas (mates) Lv.5", fr:"Problèmes (maths) niv.5", de:"Mathe-Textaufgaben Lv.5", pt:"Problemas (mat.) Lv.5", ru:"Текстовые задачи ур.5", vi:"Toán đố Lv.5", th:"โจทย์ปัญหา (คณิต) Lv.5", in:"Soal cerita (mtk) Lv.5" },
bg_m_all_d: { ko:"수학 모든 영역 Lv.3 이상", en:"All math skills Lv.3+", ja:"さんすう ぜんいき Lv.3 いじょう", zh:"数学所有领域 Lv.3 以上", es:"Todas las áreas de mates Lv.3+", fr:"Toutes les compétences de maths niv.3+", de:"Alle Mathe-Bereiche Lv.3+", pt:"Todas as áreas de mat. Lv.3+", ru:"Все области математики ур.3+", vi:"Mọi mảng toán Lv.3+", th:"ทุกด้านคณิต Lv.3 ขึ้นไป", in:"Semua area mtk Lv.3+" },
bg_both: { ko:"두 과목 척척", en:"Double subject star", ja:"りょうかもく バッチリ", zh:"两科都拿手", es:"As de dos materias", fr:"Champion des deux matières", de:"Zwei Fächer top", pt:"Craque nas duas matérias", ru:"Силён в двух предметах", vi:"Giỏi cả hai môn", th:"เก่งทั้งสองวิชา", in:"Jago dua mata pelajaran" },
bg_both_d: { ko:"영어·수학 모두 Lv.3 이상 영역 보유", en:"Lv.3+ area in both English & math", ja:"えいごも さんすうも Lv.3 いじょう", zh:"英语·数学都有 Lv.3 以上领域", es:"Área Lv.3+ en inglés y mates", fr:"Niv.3+ en anglais et en maths", de:"Lv.3+ in Englisch und Mathe", pt:"Área Lv.3+ em inglês e mat.", ru:"Область ур.3+ и в английском, и в математике", vi:"Có mảng Lv.3+ ở cả Anh và Toán", th:"มีด้าน Lv.3+ ทั้งอังกฤษและคณิต", in:"Area Lv.3+ di Inggris dan matematika" },
`;

const src = fs.readFileSync(MATH, "utf8");
const mathData = require(MATH);
const out = [];
let bad = 0;
for (const [key, ko] of Object.entries(COPY)) {
  if (!mathData[key]) { console.error("수학 원장에 없음: " + key); bad++; continue; }
  if (mathData[key].ko !== ko) {
    console.error(`ko 불일치 ${key}: 수학="${mathData[key].ko}" 기대="${ko}"`);
    bad++; continue;
  }
  const m = src.match(new RegExp("^" + key + ": \\{.*$", "m"));
  if (!m) { console.error("줄을 못 찾음: " + key); bad++; continue; }
  out.push(m[0]);
}
if (bad) process.exit(1);

const body =
  "/**\n" +
  " * 실력 영역·칭호·배지 이름 — 자동 생성: node tools/i18n/make_ui_skills.js\n" +
  " * 수학 앱과 원문이 같은 키는 수학의 ui_data.js 에서 베껴 온다 (직접 고치지 말 것).\n" +
  " */\n" +
  "module.exports = {\n\n" +
  "// ---------- 수학 앱에서 베껴 온 키 ----------\n" +
  out.join("\n") + "\n" +
  EXTRA + "\n};\n";
fs.writeFileSync(path.join(__dirname, "ui_skills.js"), body, "utf8");
console.log(`복사 ${out.length}키 + 전용 키 → ui_skills.js`);
