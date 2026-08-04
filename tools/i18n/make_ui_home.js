/**
 * 홈·통계 화면 문자열 — 수학 앱과 한국어 원문이 같은 키를 수학 원장에서 그대로
 * 가져와 ui_home.js 를 만든다. 영어 앱 전용 키는 아래 EXTRA 에 직접 쓴다.
 *
 *   node tools/i18n/make_ui_home.js
 */
const fs = require("fs");
const path = require("path");

const mathAll = require("C:/workAndroid/PiyakMath/tools/i18n/strings.js").strings;
const LANGS = ["ko", "en", "ja", "zh", "es", "fr", "de", "pt", "ru", "vi", "th", "in"];

// 복사할 키와 기대하는 한국어 원문 (다르면 사고 — 멈춘다)
const COPY = {
  home_greeting: "오늘도 삐약삐약 공부해요!",
  home_no_review: "복습할 오답이 없어요! 삐약 🐥",
  goal_light: "가볍게 (레슨 1개쯤)",
  goal_normal: "보통 (레슨 2~3개)",
  goal_hard: "열심히 (레슨 5개쯤)",
  goal_beast: "빡세게 (레슨 10개쯤)",
  cancel: "취소",
  home_wrong_count: "오답 %d",
  home_overall_lv: "종합 실력 Lv.%s",
  rank_next: "  →  다음 칭호 %1$s %2$s",
  rank_next_short: "  (→ %1$s Lv.%2$.1f)",
  rank_top: "  (최고 칭호!)",
  home_daily_goal: "오늘의 목표  %1$d / %2$d XP",
  home_goal_done: "   ✅ 달성!",
  weak_area: "약한 영역: %1$s %2$s",
  not_started: "  시작 전",
  home_placement_math: "레벨테스트로 내 학년 찾기!\n25문제로 딱 맞는 단계를 정해줘요",
  stats_counters: "📚 완료한 레슨  %1$d개\n💯 퍼펙트 레슨  %2$d개\n💊 클리어한 오답  %3$d개\n🗓 공부한 날  %4$d일",
};

const EXTRA = `
// ---------- 홈 인사말 (영어 앱 전용 문구) ----------
home_greeting_2: { ko:"꾸준함이 최고의 재능이에요 🐥", en:"Consistency is the greatest talent 🐥", ja:"つづける ことが さいこうの さいのう 🐥", zh:"坚持就是最好的天赋 🐥", es:"La constancia es el mayor talento 🐥", fr:"La régularité est le plus grand talent 🐥", de:"Dranbleiben ist das größte Talent 🐥", pt:"Constância é o maior talento 🐥", ru:"Постоянство — главный талант 🐥", vi:"Kiên trì là tài năng lớn nhất 🐥", th:"ความสม่ำเสมอคือพรสวรรค์ที่ดีที่สุด 🐥", in:"Konsisten adalah bakat terbaik 🐥" },
home_greeting_3: { ko:"한 문제라도 풀면 오늘은 성공!", en:"Solve even one question and today's a win!", ja:"1もんでも とけたら きょうは せいこう!", zh:"哪怕只做一题，今天也算成功!", es:"¡Con una sola pregunta, hoy ya es un éxito!", fr:"Une seule question résolue et la journée est gagnée !", de:"Schon eine Aufgabe gelöst — heute ist ein Erfolg!", pt:"Resolveu uma questão? O dia já valeu!", ru:"Решил хоть одну задачу — день удался!", vi:"Giải dù một câu thôi, hôm nay đã thành công!", th:"แค่ทำได้ข้อเดียว วันนี้ก็สำเร็จแล้ว!", in:"Kerjakan satu soal saja, hari ini sudah sukses!" },
home_greeting_4: { ko:"삐약! 영어가 무서우면 저를 봐요!", en:"Peep! Scared of English? Look at me!", ja:"ピヨ! えいごが こわいときは わたしを みてね!", zh:"叽叽! 怕英语的话就看看我!", es:"¡Pío! ¿Miedo al inglés? ¡Mírame!", fr:"Cui-cui ! Peur de l'anglais ? Regarde-moi !", de:"Piep! Angst vor Englisch? Schau mich an!", pt:"Piu! Medo de inglês? Olhe para mim!", ru:"Пи-пи! Боишься английского? Смотри на меня!", vi:"Chíp chíp! Sợ tiếng Anh ư? Nhìn tớ này!", th:"จิ๊บ! กลัวภาษาอังกฤษเหรอ มองฉันสิ!", in:"Ciap! Takut bahasa Inggris? Lihat aku!" },
home_greeting_5: { ko:"어제의 나보다 한 단어 더!", en:"One more word than yesterday's me!", ja:"きのうの じぶんより 1たんご おおく!", zh:"比昨天的自己多一个单词!", es:"¡Una palabra más que ayer!", fr:"Un mot de plus qu'hier !", de:"Ein Wort mehr als gestern!", pt:"Uma palavra a mais que ontem!", ru:"На одно слово больше, чем вчера!", vi:"Hơn mình hôm qua một từ!", th:"มากกว่าเมื่อวานอีกหนึ่งคำ!", in:"Satu kata lebih banyak dari kemarin!" },
home_greeting_6: { ko:"여행 가서 써먹을 그날까지 ✈️", en:"Until the day you use it on a trip ✈️", ja:"りょこうで つかえる ひまで ✈️", zh:"直到旅行时用上的那天 ✈️", es:"Hasta el día que lo uses de viaje ✈️", fr:"Jusqu'au jour où tu t'en serviras en voyage ✈️", de:"Bis zu dem Tag, an dem du es auf Reisen brauchst ✈️", pt:"Até o dia de usar numa viagem ✈️", ru:"До того дня, когда пригодится в путешествии ✈️", vi:"Đến ngày dùng được khi đi du lịch ✈️", th:"จนถึงวันที่ได้ใช้ตอนไปเที่ยว ✈️", in:"Sampai hari kamu memakainya saat liburan ✈️" },

// ---------- 레벨테스트 배너 (영어판) ----------
home_placement_en: { ko:"레벨테스트로 내 위치 찾기!\\n25문제로 딱 맞는 레벨을 정해줘요", en:"Find your level with a placement test!\\n25 questions pick the right level for you", ja:"レベルテストで じぶんの いちを みつけよう!\\n25もんで ぴったりの レベルを きめるよ", zh:"用分级测试找到你的位置!\\n25道题帮你定好合适的级别", es:"¡Encuentra tu nivel con la prueba!\\n25 preguntas eligen el nivel perfecto", fr:"Trouve ton niveau avec le test !\\n25 questions choisissent le bon niveau", de:"Finde dein Level mit dem Einstufungstest!\\n25 Fragen bestimmen die richtige Stufe", pt:"Descubra seu nível com o teste!\\n25 questões definem o nível certo", ru:"Найди свой уровень с тестом!\\n25 вопросов подберут подходящий уровень", vi:"Tìm trình độ của bạn bằng bài kiểm tra!\\n25 câu chọn đúng cấp độ cho bạn", th:"หาระดับของคุณด้วยแบบทดสอบ!\\n25 ข้อช่วยเลือกระดับที่เหมาะสม", in:"Temukan levelmu lewat tes penempatan!\\n25 soal menentukan level yang pas" },

// ---------- 홈 단계 카드 5장 ----------
stage_kinder: { ko:"유치원 영어", en:"Preschool English", ja:"ようちえん えいご", zh:"幼儿英语", es:"Inglés preescolar", fr:"Anglais maternelle", de:"Kindergarten-Englisch", pt:"Inglês infantil", ru:"Английский для малышей", vi:"Tiếng Anh mầm non", th:"อังกฤษอนุบาล", in:"Inggris TK" },
stage_kinder_sub: { ko:"알파벳 쓰기 · 놀이터", en:"Alphabet writing · Playground", ja:"アルファベット かき · あそびば", zh:"字母书写 · 游乐场", es:"Escribir el alfabeto · Zona de juegos", fr:"Écriture de l'alphabet · Aire de jeux", de:"Alphabet schreiben · Spielplatz", pt:"Escrever o alfabeto · Parquinho", ru:"Письмо алфавита · Игровая площадка", vi:"Viết bảng chữ cái · Sân chơi", th:"หัดเขียนตัวอักษร · สนามเด็กเล่น", in:"Menulis alfabet · Taman bermain" },
stage_elem: { ko:"초등 영어", en:"Elementary English", ja:"しょうがく えいご", zh:"小学英语", es:"Inglés de primaria", fr:"Anglais primaire", de:"Grundschul-Englisch", pt:"Inglês fundamental", ru:"Английский для начальной школы", vi:"Tiếng Anh tiểu học", th:"อังกฤษประถม", in:"Inggris SD" },
stage_elem_sub: { ko:"초등영어 코스 · 기초 1~6학년", en:"Elementary course · Basics grades 1–6", ja:"しょうがく コース · きそ 1~6ねん", zh:"小学课程 · 基础1~6年级", es:"Curso de primaria · Básico 1º–6º", fr:"Cours primaire · Bases années 1–6", de:"Grundschulkurs · Basis Klasse 1–6", pt:"Curso fundamental · Básico 1º–6º ano", ru:"Курс начальной школы · Базовый 1–6 класс", vi:"Khóa tiểu học · Cơ bản lớp 1–6", th:"คอร์สประถม · พื้นฐาน ป.1–6", in:"Kursus SD · Dasar kelas 1–6" },
stage_middle: { ko:"중등 · 고등 영어", en:"Middle & high school English", ja:"ちゅうがく · こうこう えいご", zh:"初中·高中英语", es:"Inglés de secundaria", fr:"Anglais collège · lycée", de:"Mittel- und Oberstufen-Englisch", pt:"Inglês do ensino médio", ru:"Английский для средней и старшей школы", vi:"Tiếng Anh THCS · THPT", th:"อังกฤษมัธยม", in:"Inggris SMP · SMA" },
stage_middle_sub: { ko:"학년별 기초 · 문법 · 독해", en:"Basics by grade · Grammar · Reading", ja:"がくねんべつ きそ · ぶんぽう · どっかい", zh:"按年级基础 · 语法 · 阅读", es:"Base por curso · Gramática · Lectura", fr:"Bases par niveau · Grammaire · Lecture", de:"Basis je Klasse · Grammatik · Lesen", pt:"Básico por ano · Gramática · Leitura", ru:"База по классам · Грамматика · Чтение", vi:"Cơ bản theo lớp · Ngữ pháp · Đọc hiểu", th:"พื้นฐานตามชั้น · ไวยากรณ์ · การอ่าน", in:"Dasar per kelas · Tata bahasa · Membaca" },
stage_adult: { ko:"성인 · 실전 영어", en:"Adult & practical English", ja:"おとな · じっせん えいご", zh:"成人·实用英语", es:"Inglés adulto y práctico", fr:"Anglais adulte · pratique", de:"Erwachsenen- und Praxis-Englisch", pt:"Inglês adulto e prático", ru:"Английский для взрослых · практика", vi:"Tiếng Anh người lớn · thực chiến", th:"อังกฤษผู้ใหญ่ · ใช้จริง", in:"Inggris dewasa · praktis" },
stage_adult_sub: { ko:"회화 · 토익 · 토플", en:"Conversation · TOEIC · TOEFL", ja:"かいわ · TOEIC · TOEFL", zh:"会话 · 托业 · 托福", es:"Conversación · TOEIC · TOEFL", fr:"Conversation · TOEIC · TOEFL", de:"Konversation · TOEIC · TOEFL", pt:"Conversação · TOEIC · TOEFL", ru:"Разговор · TOEIC · TOEFL", vi:"Hội thoại · TOEIC · TOEFL", th:"สนทนา · TOEIC · TOEFL", in:"Percakapan · TOEIC · TOEFL" },
stage_skills: { ko:"영역별 훈련", en:"Skill-by-skill training", ja:"ぶんやべつ トレーニング", zh:"分领域训练", es:"Entrenamiento por áreas", fr:"Entraînement par compétence", de:"Training nach Bereich", pt:"Treino por área", ru:"Тренировка по областям", vi:"Luyện theo kỹ năng", th:"ฝึกตามทักษะ", in:"Latihan per area" },
stage_skills_sub: { ko:"듣기 · 말하기 · 쓰기 · 문법 · 독해", en:"Listening · Speaking · Writing · Grammar · Reading", ja:"リスニング · スピーキング · ライティング · ぶんぽう · どっかい", zh:"听力 · 口语 · 写作 · 语法 · 阅读", es:"Escucha · Habla · Escritura · Gramática · Lectura", fr:"Écoute · Oral · Écriture · Grammaire · Lecture", de:"Hören · Sprechen · Schreiben · Grammatik · Lesen", pt:"Escuta · Fala · Escrita · Gramática · Leitura", ru:"Аудирование · Говорение · Письмо · Грамматика · Чтение", vi:"Nghe · Nói · Viết · Ngữ pháp · Đọc", th:"ฟัง · พูด · เขียน · ไวยากรณ์ · อ่าน", in:"Menyimak · Berbicara · Menulis · Tata bahasa · Membaca" },
`;

let bad = 0;
const out = [];
for (const [key, ko] of Object.entries(COPY)) {
  const v = mathAll[key];
  if (!v) { console.error("수학 원장에 없음: " + key); bad++; continue; }
  if (v.ko !== ko) { console.error(`ko 불일치 ${key}: "${v.ko}"`); bad++; continue; }
  const parts = LANGS.map((lg) => {
    if (v[lg] == null) { console.error(`번역 없음 ${key}.${lg}`); bad++; return ""; }
    return `${lg}:${JSON.stringify(v[lg])}`;
  });
  out.push(`${key}: { ${parts.join(", ")} },`);
}
if (bad) process.exit(1);

const body =
  "/**\n" +
  " * 홈·통계 화면 문자열 — 자동 생성: node tools/i18n/make_ui_home.js\n" +
  " * 수학 앱과 원문이 같은 키는 수학 원장에서 베껴 온다 (직접 고치지 말 것).\n" +
  " */\n" +
  "module.exports = {\n\n" +
  "// ---------- 수학 앱에서 베껴 온 키 ----------\n" +
  out.join("\n") + "\n" +
  EXTRA + "\n};\n";
fs.writeFileSync(path.join(__dirname, "ui_home.js"), body, "utf8");
console.log(`복사 ${out.length}키 + 전용 키 → ui_home.js`);
