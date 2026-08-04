/**
 * 삐약영어 다국어 문자열 원장.
 *
 * 기본 언어는 **영어**(values/) — 지원하지 않는 언어의 폰은 여기로 떨어진다.
 * 한국어는 values-ko/ 에 들어간다. 번체 중국어(zh-rTW·zh-rHK)는 zh 에서 자동 변환.
 *
 * 고친 뒤에는 반드시:  node tools/i18n/gen_strings.js
 *
 * 지금은 **언어 분기에 쓰이는 문구만** 있다 (문제 화면의 듣기 전환 등).
 * 나머지 UI 370여 종은 다음 단계에서 화면별 파일로 나눠 채운다.
 */
module.exports = {
  // zh 는 간체, zh-rTW·zh-rHK 는 번체 — 번체는 원장에 안 쓰고 zh 에서 자동 변환한다
  langs: ["en", "ko", "ja", "zh", "zh-rTW", "zh-rHK", "es", "fr", "de", "pt", "ru", "vi", "th", "in"],
  strings: {
    // 앱 이름 — 영어권 표기는 로마자, 각 언어는 제 문자로
    app_name: { ko: "삐약영어", en: "Piyak English", ja: "ピヤックえいご", zh: "啾啾英语", es: "Piyak English", fr: "Piyak English", de: "Piyak English", pt: "Piyak English", ru: "Piyak English", vi: "Piyak English", th: "Piyak English", in: "Piyak English" },

    // ---------- 한국어를 못 읽는 폰에서의 문제 전환 ----------
    // 그림을 보여 주고 영어를 묻는다 (원래는 "…를 영어로?" 에 한국어 뜻이 들어간다)
    ask_pic_en: { ko: "이 그림은 영어로 무엇일까요?", en: "What is this picture in English?", ja: "この えは えいごで なに?", zh: "这张图用英语怎么说?", es: "¿Cómo se dice este dibujo en inglés?", fr: "Comment dit-on cette image en anglais ?", de: "Was ist dieses Bild auf Englisch?", pt: "Como se diz esta figura em inglês?", ru: "Как это будет по-английски?", vi: "Hình này tiếng Anh là gì?", th: "รูปนี้ภาษาอังกฤษเรียกว่าอะไร?", in: "Gambar ini bahasa Inggrisnya apa?" },
    // 단어 배열: 한국어 문장 대신 영어 문장을 들려 주고 순서를 맞추게 한다
    listen_arrange: { ko: "듣고 순서대로 배열해 보세요", en: "Listen and arrange the words in order", ja: "きいて じゅんばんに ならべよう", zh: "听一听，把单词按顺序排好", es: "Escucha y ordena las palabras", fr: "Écoute et mets les mots dans l'ordre", de: "Hör zu und bring die Wörter in die richtige Reihenfolge", pt: "Ouça e coloque as palavras em ordem", ru: "Послушай и расставь слова по порядку", vi: "Nghe và sắp xếp các từ theo thứ tự", th: "ฟังแล้วเรียงคำตามลำดับ", in: "Dengarkan lalu susun kata-katanya" },
    // 영작 타이핑: 한국어 문장 대신 영어 문장을 들려 주고 받아 적게 한다
    listen_type: { ko: "듣고 영어로 써 보세요", en: "Listen and type what you hear", ja: "きいて えいごで かいてみよう", zh: "听一听，把听到的用英语写下来", es: "Escucha y escribe lo que oigas", fr: "Écoute et écris ce que tu entends", de: "Hör zu und schreib, was du hörst", pt: "Ouça e escreva o que ouvir", ru: "Послушай и напиши, что услышал", vi: "Nghe và gõ lại những gì bạn nghe", th: "ฟังแล้วพิมพ์สิ่งที่ได้ยิน", in: "Dengarkan lalu ketik yang kamu dengar" },
    // 다시 듣기 버튼
    play_again: { ko: "🔊 다시 듣기", en: "🔊 Play again", ja: "🔊 もういちど きく", zh: "🔊 再听一遍", es: "🔊 Escuchar otra vez", fr: "🔊 Réécouter", de: "🔊 Noch mal anhören", pt: "🔊 Ouvir de novo", ru: "🔊 Прослушать ещё раз", vi: "🔊 Nghe lại", th: "🔊 ฟังอีกครั้ง", in: "🔊 Putar lagi" },
  },
};

// 문제 화면 문자열 — 수학 앱과 같은 코드에서 갈라져 한국어 원문이 동일하다.
// 같은 원장을 재사용한다 (안 쓰는 키는 리소스로만 남고 무해하다).
Object.assign(module.exports.strings, require("./ui_lesson"), require("./ui_en_lesson"), require("./ui_result"), require("./ui_skills"), require("./ui_home"));
