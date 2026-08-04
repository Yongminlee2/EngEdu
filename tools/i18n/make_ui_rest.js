/**
 * 나머지 화면(레벨테스트·설정·게임·알파벳·레이아웃 고정 문구) 문자열.
 * 수학 앱과 원문이 같은 키는 수학 원장에서 베껴 오고, 전용 키는 EXTRA 에 쓴다.
 *
 *   node tools/i18n/make_ui_rest.js   →  ui_rest.js
 */
const fs = require("fs");
const path = require("path");

const mathAll = require("C:/workAndroid/PiyakMath/tools/i18n/strings.js").strings;
const LANGS = ["ko", "en", "ja", "zh", "es", "fr", "de", "pt", "ru", "vi", "th", "in"];

const COPY = {
  crash_title: "마지막 오류 기록",
  copy: "복사",
  copied: "복사했어요",
  locked_lesson: "앞의 레슨을 먼저 완료해 주세요! 🥚",
  done: "완료",
  start: "시작하기",
  home_my_skill: "내 실력",
  home_courses: "학습 코스",
  home_settings: "설정",
  home_stats: "통계",
  placement_title: "레벨테스트",
  placement_quit_ask: "레벨테스트를 그만둘까요?",
  placement_level: "레벨 %1$d",
  placement_done: "%1$s 레벨테스트 완료",
  placement_coins: "💰 용돈 +%1$s",
  placement_msg_math: "%1$s 수준이에요!\n%1$s까지 모든 단원을 열어 드렸어요.\n+30 XP 🎁",
};

const EXTRA = `
// ---------- 레벨테스트 (영어판) ----------
placement_msg_en: { ko:"%1$s 수준이에요!\\n기초 트랙 레벨 %2$d까지 열어 드렸어요.\\n+30 XP 🎁", en:"You're at %1$s level!\\nBasic track is open up to level %2$d.\\n+30 XP 🎁", ja:"%1$s レベルだよ!\\nきそトラックを レベル %2$d まで あけたよ。\\n+30 XP 🎁", zh:"你的水平是 %1$s!\\n基础轨道开放到级别 %2$d。\\n+30 XP 🎁", es:"¡Tu nivel es %1$s!\\nPista básica abierta hasta el nivel %2$d.\\n+30 XP 🎁", fr:"Ton niveau : %1$s !\\nPiste de base ouverte jusqu'au niveau %2$d.\\n+30 XP 🎁", de:"Dein Niveau: %1$s!\\nBasis-Track bis Level %2$d freigeschaltet.\\n+30 XP 🎁", pt:"Seu nível é %1$s!\\nTrilha básica aberta até o nível %2$d.\\n+30 XP 🎁", ru:"Твой уровень: %1$s!\\nБазовый трек открыт до уровня %2$d.\\n+30 XP 🎁", vi:"Trình độ của bạn là %1$s!\\nĐã mở lộ trình cơ bản đến cấp %2$d.\\n+30 XP 🎁", th:"ระดับของคุณคือ %1$s!\\nเปิดคอร์สพื้นฐานถึงระดับ %2$d แล้ว\\n+30 XP 🎁", in:"Levelmu %1$s!\\nJalur dasar terbuka sampai level %2$d.\\n+30 XP 🎁" },
lv_1: { ko:"초등 1~2학년", en:"Grades 1–2", ja:"しょう1~2ねん", zh:"小学1~2年级", es:"1º–2º de primaria", fr:"Années 1–2", de:"Klasse 1–2", pt:"1º–2º ano", ru:"1–2 класс", vi:"Lớp 1–2", th:"ป.1–2", in:"Kelas 1–2" },
lv_2: { ko:"초등 3~4학년", en:"Grades 3–4", ja:"しょう3~4ねん", zh:"小学3~4年级", es:"3º–4º de primaria", fr:"Années 3–4", de:"Klasse 3–4", pt:"3º–4º ano", ru:"3–4 класс", vi:"Lớp 3–4", th:"ป.3–4", in:"Kelas 3–4" },
lv_3: { ko:"초등 5~6학년", en:"Grades 5–6", ja:"しょう5~6ねん", zh:"小学5~6年级", es:"5º–6º de primaria", fr:"Années 5–6", de:"Klasse 5–6", pt:"5º–6º ano", ru:"5–6 класс", vi:"Lớp 5–6", th:"ป.5–6", in:"Kelas 5–6" },
lv_4: { ko:"중학 1학년", en:"Middle school 1", ja:"ちゅう1", zh:"初一", es:"Secundaria 1", fr:"Collège 1", de:"Mittelstufe 1", pt:"Ginásio 1", ru:"Средняя школа 1", vi:"Lớp 7", th:"ม.1", in:"SMP 1" },
lv_5: { ko:"중학 2학년", en:"Middle school 2", ja:"ちゅう2", zh:"初二", es:"Secundaria 2", fr:"Collège 2", de:"Mittelstufe 2", pt:"Ginásio 2", ru:"Средняя школа 2", vi:"Lớp 8", th:"ม.2", in:"SMP 2" },
lv_6: { ko:"중학 3학년", en:"Middle school 3", ja:"ちゅう3", zh:"初三", es:"Secundaria 3", fr:"Collège 3", de:"Mittelstufe 3", pt:"Ginásio 3", ru:"Средняя школа 3", vi:"Lớp 9", th:"ม.3", in:"SMP 3" },
lv_7: { ko:"고등 1학년", en:"High school 1", ja:"こう1", zh:"高一", es:"Bachillerato 1", fr:"Lycée 1", de:"Oberstufe 1", pt:"Colegial 1", ru:"Старшая школа 1", vi:"Lớp 10", th:"ม.4", in:"SMA 1" },
lv_8: { ko:"고등 2~3학년", en:"High school 2–3", ja:"こう2~3", zh:"高二~高三", es:"Bachillerato 2–3", fr:"Lycée 2–3", de:"Oberstufe 2–3", pt:"Colegial 2–3", ru:"Старшая школа 2–3", vi:"Lớp 11–12", th:"ม.5–6", in:"SMA 2–3" },
lv_9: { ko:"성인·토익 중급", en:"Adult · TOEIC intermediate", ja:"おとな · TOEIC ちゅうきゅう", zh:"成人·托业中级", es:"Adulto · TOEIC intermedio", fr:"Adulte · TOEIC intermédiaire", de:"Erwachsene · TOEIC Mittelstufe", pt:"Adulto · TOEIC intermediário", ru:"Взрослый · TOEIC средний", vi:"Người lớn · TOEIC trung cấp", th:"ผู้ใหญ่ · TOEIC ระดับกลาง", in:"Dewasa · TOEIC menengah" },
lv_10: { ko:"고급·토플", en:"Advanced · TOEFL", ja:"じょうきゅう · TOEFL", zh:"高级·托福", es:"Avanzado · TOEFL", fr:"Avancé · TOEFL", de:"Fortgeschritten · TOEFL", pt:"Avançado · TOEFL", ru:"Продвинутый · TOEFL", vi:"Nâng cao · TOEFL", th:"ระดับสูง · TOEFL", in:"Mahir · TOEFL" },
sub_english: { ko:"영어", en:"English", ja:"えいご", zh:"英语", es:"Inglés", fr:"Anglais", de:"Englisch", pt:"Inglês", ru:"Английский", vi:"Tiếng Anh", th:"ภาษาอังกฤษ", in:"Bahasa Inggris" },
sub_math: { ko:"수학", en:"Math", ja:"さんすう", zh:"数学", es:"Mates", fr:"Maths", de:"Mathe", pt:"Matemática", ru:"Математика", vi:"Toán", th:"คณิต", in:"Matematika" },

// ---------- 설정 ----------
reset_ask: { ko:"정말 초기화할까요?", en:"Really reset everything?", ja:"ほんとうに リセットする?", zh:"真的要重置吗?", es:"¿Seguro que quieres reiniciar?", fr:"Vraiment tout réinitialiser ?", de:"Wirklich alles zurücksetzen?", pt:"Redefinir tudo mesmo?", ru:"Точно сбросить всё?", vi:"Thật sự đặt lại tất cả?", th:"จะรีเซ็ตจริง ๆ ไหม?", in:"Benar-benar mau reset?" },
reset_msg: { ko:"모든 진행도·XP·배지·오답이 삭제돼요.\\n되돌릴 수 없어요!", en:"All progress, XP, badges and wrong-answer notes will be deleted.\\nThis can't be undone!", ja:"すべての しんこう·XP·バッジ·まちがいが きえるよ。\\nもとに もどせないよ!", zh:"所有进度·XP·徽章·错题都会被删除。\\n无法恢复!", es:"Se borrarán todo el progreso, XP, insignias y errores.\\n¡No se puede deshacer!", fr:"Toute la progression, XP, badges et erreurs seront effacés.\\nIrréversible !", de:"Fortschritt, XP, Abzeichen und Fehler werden gelöscht.\\nNicht rückgängig zu machen!", pt:"Todo o progresso, XP, distintivos e erros serão apagados.\\nNão dá para desfazer!", ru:"Весь прогресс, XP, значки и ошибки будут удалены.\\nЭто нельзя отменить!", vi:"Mọi tiến độ, XP, huy hiệu, câu sai sẽ bị xóa.\\nKhông thể hoàn tác!", th:"ความคืบหน้า XP เหรียญ และข้อผิดทั้งหมดจะถูกลบ\\nย้อนกลับไม่ได้!", in:"Semua progres, XP, lencana, dan catatan salah akan dihapus.\\nTidak bisa dibatalkan!" },
reset_do: { ko:"초기화", en:"Reset", ja:"リセット", zh:"重置", es:"Reiniciar", fr:"Réinitialiser", de:"Zurücksetzen", pt:"Redefinir", ru:"Сбросить", vi:"Đặt lại", th:"รีเซ็ต", in:"Reset" },
reset_done: { ko:"초기화 완료! 처음부터 삐약! 🐣", en:"Reset complete! Fresh start, peep! 🐣", ja:"リセット かんりょう! さいしょから ピヨ! 🐣", zh:"重置完成! 从头开始叽叽! 🐣", es:"¡Reinicio completo! ¡Desde cero, pío! 🐣", fr:"Réinitialisé ! On repart de zéro, cui-cui ! 🐣", de:"Zurückgesetzt! Neustart, piep! 🐣", pt:"Redefinido! Começo do zero, piu! 🐣", ru:"Сброшено! Начинаем сначала, пи-пи! 🐣", vi:"Đã đặt lại! Bắt đầu lại nào, chíp! 🐣", th:"รีเซ็ตแล้ว! เริ่มใหม่ จิ๊บ! 🐣", in:"Reset selesai! Mulai dari awal, ciap! 🐣" },

// ---------- 미니게임 ----------
game_minigame: { ko:"미니게임", en:"Mini game", ja:"ミニゲーム", zh:"小游戏", es:"Minijuego", fr:"Mini-jeu", de:"Minispiel", pt:"Minijogo", ru:"Мини-игра", vi:"Trò chơi nhỏ", th:"มินิเกม", in:"Gim mini" },
game_time_up: { ko:"시간 끝!", en:"Time's up!", ja:"じかん おわり!", zh:"时间到!", es:"¡Se acabó el tiempo!", fr:"Temps écoulé !", de:"Zeit ist um!", pt:"Acabou o tempo!", ru:"Время вышло!", vi:"Hết giờ!", th:"หมดเวลา!", in:"Waktu habis!" },
game_lost: { ko:"아쉬워요!", en:"So close!", ja:"ざんねん!", zh:"好可惜!", es:"¡Casi!", fr:"Dommage !", de:"Knapp daneben!", pt:"Foi por pouco!", ru:"Почти получилось!", vi:"Tiếc quá!", th:"เสียดายจัง!", in:"Sayang sekali!" },
game_basket_done: { ko:"다 담았어요!", en:"All in the basket!", ja:"ぜんぶ いれたよ!", zh:"全装好了!", es:"¡Todo en la cesta!", fr:"Tout est dans le panier !", de:"Alles im Korb!", pt:"Tudo na cesta!", ru:"Всё в корзине!", vi:"Đã bỏ hết vào giỏ!", th:"ใส่ครบแล้ว!", in:"Semua sudah masuk!" },
game_all_done: { ko:"다 풀었어요!", en:"All done!", ja:"ぜんぶ できた!", zh:"全做完了!", es:"¡Todo hecho!", fr:"Tout est fini !", de:"Alles geschafft!", pt:"Tudo feito!", ru:"Всё решено!", vi:"Làm xong hết rồi!", th:"ทำครบแล้ว!", in:"Selesai semua!" },
game_match_math: { ko:"짝이 맞는 것끼리 이어요", en:"Connect the matching pairs", ja:"あう ペアを つなごう", zh:"把配对的连起来", es:"Une las parejas que coinciden", fr:"Relie les paires qui vont ensemble", de:"Verbinde die passenden Paare", pt:"Ligue os pares que combinam", ru:"Соедини подходящие пары", vi:"Nối các cặp khớp nhau", th:"ลากเส้นจับคู่ที่เข้ากัน", in:"Hubungkan pasangan yang cocok" },
game_match_en: { ko:"그림과 낱말을 이어요", en:"Match pictures with words", ja:"えと ことばを つなごう", zh:"把图和单词连起来", es:"Une dibujos y palabras", fr:"Relie images et mots", de:"Verbinde Bilder und Wörter", pt:"Ligue figuras e palavras", ru:"Соедини картинки и слова", vi:"Nối hình với từ", th:"จับคู่รูปกับคำ", in:"Hubungkan gambar dan kata" },
game_score: { ko:"점수 %1$d점 · +%2$d XP", en:"Score %1$d · +%2$d XP", ja:"スコア %1$d てん · +%2$d XP", zh:"得分 %1$d · +%2$d XP", es:"Puntos %1$d · +%2$d XP", fr:"Score %1$d · +%2$d XP", de:"Punkte %1$d · +%2$d XP", pt:"Pontos %1$d · +%2$d XP", ru:"Очки %1$d · +%2$d XP", vi:"Điểm %1$d · +%2$d XP", th:"คะแนน %1$d · +%2$d XP", in:"Skor %1$d · +%2$d XP" },
game_no_more_coins: { ko:"오늘 게임 용돈은 다 받았어요\\n(공부하면 더 받을 수 있어요!)", en:"Today's game money is all collected\\n(study to earn more!)", ja:"きょうの ゲーム おこづかいは もらいきったよ\\n(べんきょうすれば もっと もらえる!)", zh:"今天游戏零花钱已领完\\n(学习还能再赚!)", es:"Ya recibiste el dinero de juegos de hoy\\n(¡estudia para ganar más!)", fr:"L'argent des jeux d'aujourd'hui est épuisé\\n(étudie pour en gagner plus !)", de:"Das Spielgeld für heute ist aufgebraucht\\n(lerne, um mehr zu verdienen!)", pt:"A mesada de jogos de hoje acabou\\n(estude para ganhar mais!)", ru:"Игровые деньги на сегодня закончились\\n(учись, чтобы заработать ещё!)", vi:"Tiền chơi game hôm nay đã nhận hết\\n(học để nhận thêm nhé!)", th:"เงินจากเกมวันนี้รับครบแล้ว\\n(เรียนต่อเพื่อรับเพิ่ม!)", in:"Uang gim hari ini sudah habis\\n(belajar untuk dapat lagi!)" },
game_balloon: { ko:"풍선 터뜨리기", en:"Balloon pop", ja:"ふうせんわり", zh:"戳气球", es:"Explota globos", fr:"Éclate-ballons", de:"Ballons platzen", pt:"Estoura balões", ru:"Лопни шарик", vi:"Bắn bóng bay", th:"เจาะลูกโป่ง", in:"Pecahkan balon" },
game_balloon_math_d: { ko:"떠오르는 풍선 중 정답을 터뜨려요", en:"Pop the balloon with the right answer", ja:"ただしい こたえの ふうせんを わろう", zh:"戳破正确答案的气球", es:"Explota el globo con la respuesta correcta", fr:"Éclate le ballon de la bonne réponse", de:"Platze den Ballon mit der richtigen Antwort", pt:"Estoure o balão da resposta certa", ru:"Лопни шарик с правильным ответом", vi:"Bắn quả bóng có đáp án đúng", th:"เจาะลูกโป่งที่มีคำตอบถูก", in:"Pecahkan balon dengan jawaban benar" },
game_balloon_en_d: { ko:"들리는 낱말의 그림 풍선을 터뜨려요", en:"Pop the picture balloon of the word you hear", ja:"きこえた ことばの え の ふうせんを わろう", zh:"戳破你听到的单词的图画气球", es:"Explota el globo del dibujo de la palabra que oigas", fr:"Éclate le ballon-image du mot entendu", de:"Platze den Bildballon des gehörten Wortes", pt:"Estoure o balão da figura da palavra ouvida", ru:"Лопни шарик с картинкой услышанного слова", vi:"Bắn quả bóng hình của từ bạn nghe", th:"เจาะลูกโป่งรูปของคำที่ได้ยิน", in:"Pecahkan balon gambar kata yang kamu dengar" },
game_basket: { ko:"바구니에 담기", en:"Fill the basket", ja:"かごに いれる", zh:"装进篮子", es:"Llena la cesta", fr:"Remplis le panier", de:"In den Korb", pt:"Encha a cesta", ru:"Наполни корзину", vi:"Bỏ vào giỏ", th:"ใส่ตะกร้า", in:"Isi keranjang" },
game_basket_d: { ko:"손가락으로 끌어서 개수만큼 담아요", en:"Drag with your finger to add the right amount", ja:"ゆびで ドラッグして かずだけ いれよう", zh:"用手指拖，装对数量", es:"Arrastra con el dedo la cantidad justa", fr:"Fais glisser le bon nombre avec le doigt", de:"Zieh mit dem Finger die richtige Menge hinein", pt:"Arraste com o dedo a quantidade certa", ru:"Перетащи пальцем нужное количество", vi:"Kéo bằng ngón tay đủ số lượng", th:"ลากด้วยนิ้วให้ครบจำนวน", in:"Seret dengan jari sebanyak jumlahnya" },
game_line: { ko:"선으로 잇기", en:"Line match", ja:"せんつなぎ", zh:"连线", es:"Une con líneas", fr:"Relie les lignes", de:"Linien verbinden", pt:"Ligue as linhas", ru:"Соедини линиями", vi:"Nối đường", th:"ลากเส้นจับคู่", in:"Hubungkan garis" },
game_line_math_d: { ko:"짝이 맞는 것끼리 손가락으로 이어요", en:"Draw lines between matching pairs", ja:"あう ペアを ゆびで つなごう", zh:"用手指把配对的连起来", es:"Une con el dedo las parejas", fr:"Relie les paires avec le doigt", de:"Verbinde passende Paare mit dem Finger", pt:"Ligue os pares com o dedo", ru:"Соедини пальцем подходящие пары", vi:"Dùng ngón tay nối các cặp", th:"ใช้นิ้วลากเส้นจับคู่", in:"Hubungkan pasangan dengan jari" },
game_line_en_d: { ko:"그림과 낱말을 손가락으로 이어요", en:"Draw lines from pictures to words", ja:"えと ことばを ゆびで つなごう", zh:"用手指把图和单词连起来", es:"Une dibujos y palabras con el dedo", fr:"Relie images et mots avec le doigt", de:"Verbinde Bilder und Wörter mit dem Finger", pt:"Ligue figuras e palavras com o dedo", ru:"Соедини пальцем картинки и слова", vi:"Dùng ngón tay nối hình với từ", th:"ใช้นิ้วลากเส้นจับคู่รูปกับคำ", in:"Hubungkan gambar dan kata dengan jari" },

// ---------- 레이아웃 고정 문구: 홈 ----------
ly_quick: { ko:"내 실력 · 상점 · 레벨테스트", en:"My skills · Shop · Level test", ja:"じつりょく · ショップ · レベルテスト", zh:"我的实力 · 商店 · 分级测试", es:"Mi nivel · Tienda · Prueba", fr:"Mon niveau · Boutique · Test", de:"Mein Können · Shop · Einstufungstest", pt:"Meu nível · Loja · Teste", ru:"Мой уровень · Магазин · Тест", vi:"Trình độ · Cửa hàng · Kiểm tra", th:"ฝีมือของฉัน · ร้านค้า · แบบทดสอบ", in:"Kemampuanku · Toko · Tes level" },
ly_stats: { ko:"📊 내 통계", en:"📊 My stats", ja:"📊 わたしの とうけい", zh:"📊 我的统计", es:"📊 Mis estadísticas", fr:"📊 Mes statistiques", de:"📊 Meine Statistik", pt:"📊 Minhas estatísticas", ru:"📊 Моя статистика", vi:"📊 Thống kê của tôi", th:"📊 สถิติของฉัน", in:"📊 Statistikku" },
ly_wallet: { ko:"💰 내 지갑", en:"💰 My wallet", ja:"💰 さいふ", zh:"💰 我的钱包", es:"💰 Mi cartera", fr:"💰 Mon portefeuille", de:"💰 Mein Geldbeutel", pt:"💰 Minha carteira", ru:"💰 Мой кошелёк", vi:"💰 Ví của tôi", th:"💰 กระเป๋าของฉัน", in:"💰 Dompetku" },
ly_settings: { ko:"⚙️ 설정", en:"⚙️ Settings", ja:"⚙️ せってい", zh:"⚙️ 设置", es:"⚙️ Ajustes", fr:"⚙️ Réglages", de:"⚙️ Einstellungen", pt:"⚙️ Configurações", ru:"⚙️ Настройки", vi:"⚙️ Cài đặt", th:"⚙️ ตั้งค่า", in:"⚙️ Pengaturan" },
ly_shop: { ko:"🛒 상점", en:"🛒 Shop", ja:"🛒 ショップ", zh:"🛒 商店", es:"🛒 Tienda", fr:"🛒 Boutique", de:"🛒 Shop", pt:"🛒 Loja", ru:"🛒 Магазин", vi:"🛒 Cửa hàng", th:"🛒 ร้านค้า", in:"🛒 Toko" },
ly_test: { ko:"🎯 레벨테스트", en:"🎯 Level test", ja:"🎯 レベルテスト", zh:"🎯 分级测试", es:"🎯 Prueba de nivel", fr:"🎯 Test de niveau", de:"🎯 Einstufungstest", pt:"🎯 Teste de nível", ru:"🎯 Тест уровня", vi:"🎯 Kiểm tra trình độ", th:"🎯 แบบทดสอบระดับ", in:"🎯 Tes level" },
ly_playground: { ko:"🎮 놀이터", en:"🎮 Playground", ja:"🎮 あそびば", zh:"🎮 游乐场", es:"🎮 Zona de juegos", fr:"🎮 Aire de jeux", de:"🎮 Spielplatz", pt:"🎮 Parquinho", ru:"🎮 Площадка", vi:"🎮 Sân chơi", th:"🎮 สนามเด็กเล่น", in:"🎮 Taman bermain" },

// ---------- 레이아웃: 통계 ----------
ly_badges: { ko:"🏆 배지", en:"🏆 Badges", ja:"🏆 バッジ", zh:"🏆 徽章", es:"🏆 Insignias", fr:"🏆 Badges", de:"🏆 Abzeichen", pt:"🏆 Distintivos", ru:"🏆 Значки", vi:"🏆 Huy hiệu", th:"🏆 เหรียญ", in:"🏆 Lencana" },
ly_streak: { ko:"🔥 스트릭 달력", en:"🔥 Streak calendar", ja:"🔥 れんぞく カレンダー", zh:"🔥 连续打卡日历", es:"🔥 Calendario de racha", fr:"🔥 Calendrier de série", de:"🔥 Serien-Kalender", pt:"🔥 Calendário de sequência", ru:"🔥 Календарь серии", vi:"🔥 Lịch chuỗi ngày", th:"🔥 ปฏิทินสตรีค", in:"🔥 Kalender runtunan" },
ly_skill_by: { ko:"📊 영역별 실력", en:"📊 Skills by area", ja:"📊 ぶんやべつ じつりょく", zh:"📊 分领域实力", es:"📊 Nivel por áreas", fr:"📊 Niveau par domaine", de:"📊 Können je Bereich", pt:"📊 Nível por área", ru:"📊 Уровень по областям", vi:"📊 Trình độ theo mảng", th:"📊 ฝีมือรายด้าน", in:"📊 Kemampuan per area" },
ly_retest: { ko:"🎯 레벨테스트 다시 보기", en:"🎯 Retake the level test", ja:"🎯 レベルテストを もういちど", zh:"🎯 重新参加分级测试", es:"🎯 Repetir la prueba de nivel", fr:"🎯 Repasser le test de niveau", de:"🎯 Einstufungstest wiederholen", pt:"🎯 Refazer o teste de nível", ru:"🎯 Пройти тест уровня снова", vi:"🎯 Làm lại bài kiểm tra", th:"🎯 ทำแบบทดสอบอีกครั้ง", in:"🎯 Ulangi tes level" },

// ---------- 레이아웃: 지갑 ----------
ly_earned: { ko:"모은 용돈", en:"Pocket money saved", ja:"ためた おこづかい", zh:"攒下的零花钱", es:"Dinero ahorrado", fr:"Argent économisé", de:"Gespartes Taschengeld", pt:"Mesada guardada", ru:"Накопленные карманные", vi:"Tiền đã dành", th:"เงินที่เก็บได้", in:"Uang saku terkumpul" },
ly_earn_rule: { ko:"문제 1개를 처음 맞히면 10원! 같은 레슨을 다시 풀면 용돈은 없어요", en:"First-try correct = 10 won! Replaying a lesson earns nothing", ja:"はじめて せいかいで 10ウォン! おなじ レッスンを もういちど といても おこづかいは なし", zh:"第一次答对一题得10韩元! 重玩同一课没有零花钱", es:"¡Primer acierto = 10 wones! Repetir la lección no da dinero", fr:"Première bonne réponse = 10 wons ! Rejouer une leçon ne rapporte rien", de:"Erster Treffer = 10 Won! Wiederholen bringt nichts", pt:"Primeiro acerto = 10 wons! Repetir a lição não rende nada", ru:"Верно с первой попытки = 10 вон! Повтор урока ничего не даёт", vi:"Đúng lần đầu = 10 won! Chơi lại bài không có tiền", th:"ตอบถูกครั้งแรกได้ 10 วอน! เล่นบทเดิมซ้ำไม่ได้เงิน", in:"Benar percobaan pertama = 10 won! Mengulang pelajaran tidak dapat uang" },
ly_shop_cash: { ko:"상점 · 현금으로 바꾸기", en:"Shop · Cash out", ja:"ショップ · げんきんに かえる", zh:"商店 · 兑换现金", es:"Tienda · Cambiar por efectivo", fr:"Boutique · Convertir en espèces", de:"Shop · In Bargeld tauschen", pt:"Loja · Trocar por dinheiro", ru:"Магазин · Обмен на наличные", vi:"Cửa hàng · Đổi tiền mặt", th:"ร้านค้า · แลกเงินสด", in:"Toko · Tukar tunai" },
ly_cash_parent: { ko:"💵 현금으로 바꾸기 (부모님)", en:"💵 Cash out (parents)", ja:"💵 げんきんに かえる (おうちのひと)", zh:"💵 兑换现金 (家长)", es:"💵 Cambiar por efectivo (padres)", fr:"💵 Convertir en espèces (parents)", de:"💵 In Bargeld tauschen (Eltern)", pt:"💵 Trocar por dinheiro (pais)", ru:"💵 Обмен на наличные (родители)", vi:"💵 Đổi tiền mặt (bố mẹ)", th:"💵 แลกเงินสด (ผู้ปกครอง)", in:"💵 Tukar tunai (orang tua)" },
ly_log: { ko:"📜 용돈 기록", en:"📜 Money history", ja:"📜 おこづかい きろく", zh:"📜 零花钱记录", es:"📜 Historial de dinero", fr:"📜 Historique d'argent", de:"📜 Geldverlauf", pt:"📜 Histórico de mesada", ru:"📜 История карманных", vi:"📜 Lịch sử tiền", th:"📜 ประวัติเงิน", in:"📜 Riwayat uang" },
ly_change: { ko:"변경", en:"Change", ja:"へんこう", zh:"更改", es:"Cambiar", fr:"Modifier", de:"Ändern", pt:"Alterar", ru:"Изменить", vi:"Đổi", th:"เปลี่ยน", in:"Ubah" },
ly_parent_lock: { ko:"🔒 부모 설정", en:"🔒 Parent settings", ja:"🔒 ほごしゃ せってい", zh:"🔒 家长设置", es:"🔒 Ajustes de padres", fr:"🔒 Réglages parents", de:"🔒 Eltern-Einstellungen", pt:"🔒 Configurações dos pais", ru:"🔒 Родительские настройки", vi:"🔒 Cài đặt phụ huynh", th:"🔒 ตั้งค่าผู้ปกครอง", in:"🔒 Pengaturan orang tua" },

// ---------- 레이아웃: 설정 ----------
ly_tts_speed: { ko:"🔊 발음 속도", en:"🔊 Speech speed", ja:"🔊 はつおんの はやさ", zh:"🔊 发音速度", es:"🔊 Velocidad de voz", fr:"🔊 Vitesse de la voix", de:"🔊 Sprechtempo", pt:"🔊 Velocidade da fala", ru:"🔊 Скорость речи", vi:"🔊 Tốc độ phát âm", th:"🔊 ความเร็วเสียงพูด", in:"🔊 Kecepatan ucapan" },
ly_slow: { ko:"천천히", en:"Slow", ja:"ゆっくり", zh:"慢速", es:"Despacio", fr:"Lentement", de:"Langsam", pt:"Devagar", ru:"Медленно", vi:"Chậm", th:"ช้า", in:"Pelan" },
ly_normal: { ko:"보통", en:"Normal", ja:"ふつう", zh:"普通", es:"Normal", fr:"Normal", de:"Normal", pt:"Normal", ru:"Обычно", vi:"Vừa", th:"ปกติ", in:"Biasa" },
ly_sfx: { ko:"🔔 효과음 크기", en:"🔔 Sound effects volume", ja:"🔔 こうかおんの おおきさ", zh:"🔔 音效音量", es:"🔔 Volumen de efectos", fr:"🔔 Volume des effets", de:"🔔 Lautstärke der Effekte", pt:"🔔 Volume dos efeitos", ru:"🔔 Громкость эффектов", vi:"🔔 Âm lượng hiệu ứng", th:"🔔 ระดับเสียงเอฟเฟกต์", in:"🔔 Volume efek suara" },
ly_sfx_try: { ko:"🔔 들어보기", en:"🔔 Preview", ja:"🔔 きいてみる", zh:"🔔 试听", es:"🔔 Probar", fr:"🔔 Écouter", de:"🔔 Anhören", pt:"🔔 Ouvir", ru:"🔔 Прослушать", vi:"🔔 Nghe thử", th:"🔔 ลองฟัง", in:"🔔 Dengarkan" },
ly_tts_try: { ko:"🔊 들어보기", en:"🔊 Preview", ja:"🔊 きいてみる", zh:"🔊 试听", es:"🔊 Probar", fr:"🔊 Écouter", de:"🔊 Anhören", pt:"🔊 Ouvir", ru:"🔊 Прослушать", vi:"🔊 Nghe thử", th:"🔊 ลองฟัง", in:"🔊 Dengarkan" },
ly_sfx_note: { ko:"너무 크면 영어 발음이 잘 안 들려요", en:"If it's too loud, the English is hard to hear", ja:"おおきすぎると えいごの はつおんが きこえにくいよ", zh:"太大声会听不清英语发音", es:"Si está muy alto, el inglés se oye mal", fr:"Trop fort, on entend mal l'anglais", de:"Zu laut übertönt die englische Aussprache", pt:"Muito alto atrapalha ouvir o inglês", ru:"Слишком громко — английский плохо слышно", vi:"To quá sẽ khó nghe tiếng Anh", th:"ดังเกินไปจะฟังเสียงอังกฤษไม่ชัด", in:"Terlalu keras membuat bahasa Inggris sulit terdengar" },
ly_hearts_free: { ko:"끄면 틀려도 하트가 줄지 않아요 (마음껏 연습)", en:"Turn off and mistakes won't cost hearts (practice freely)", ja:"オフに すると まちがえても ハートが へらないよ (すきなだけ れんしゅう)", zh:"关闭后答错也不扣爱心 (尽情练习)", es:"Apágalo y los errores no quitan corazones (practica libre)", fr:"Désactive et les erreurs ne coûtent pas de cœurs (entraîne-toi librement)", de:"Ausschalten: Fehler kosten keine Herzen (frei üben)", pt:"Desligue e os erros não tiram corações (pratique à vontade)", ru:"Выключи — и ошибки не отнимают сердечки (свободная практика)", vi:"Tắt đi thì sai cũng không mất tim (luyện thoải mái)", th:"ปิดแล้วตอบผิดก็ไม่เสียหัวใจ (ฝึกได้เต็มที่)", in:"Matikan agar salah tidak mengurangi hati (latihan bebas)" },
ly_heart_use: { ko:"❤️ 하트 쓰기", en:"❤️ Use hearts", ja:"❤️ ハートを つかう", zh:"❤️ 使用爱心", es:"❤️ Usar corazones", fr:"❤️ Utiliser les cœurs", de:"❤️ Herzen verwenden", pt:"❤️ Usar corações", ru:"❤️ Использовать сердечки", vi:"❤️ Dùng tim", th:"❤️ ใช้หัวใจ", in:"❤️ Pakai hati" },
ly_reset_all: { ko:"🗑 진행도 전체 초기화", en:"🗑 Reset all progress", ja:"🗑 しんこうを ぜんぶ リセット", zh:"🗑 重置全部进度", es:"🗑 Reiniciar todo el progreso", fr:"🗑 Réinitialiser toute la progression", de:"🗑 Gesamten Fortschritt zurücksetzen", pt:"🗑 Redefinir todo o progresso", ru:"🗑 Сбросить весь прогресс", vi:"🗑 Đặt lại toàn bộ tiến độ", th:"🗑 รีเซ็ตความคืบหน้าทั้งหมด", in:"🗑 Reset semua progres" },
ly_errlog: { ko:"🐞 마지막 오류 기록 보기", en:"🐞 View last error log", ja:"🐞 さいごの エラーきろくを みる", zh:"🐞 查看最近错误记录", es:"🐞 Ver último registro de errores", fr:"🐞 Voir le dernier journal d'erreurs", de:"🐞 Letztes Fehlerprotokoll ansehen", pt:"🐞 Ver último registro de erro", ru:"🐞 Показать последний журнал ошибок", vi:"🐞 Xem nhật ký lỗi gần nhất", th:"🐞 ดูบันทึกข้อผิดพลาดล่าสุด", in:"🐞 Lihat log kesalahan terakhir" },
ly_about: { ko:"삐약영어 🐥 나만의 영어 공부 앱\\n말하기 채점은 인터넷이 있을 때 더 정확해요", en:"Piyak English 🐥 your very own English study app\\nSpeaking scores are more accurate with internet", ja:"ピヤックえいご 🐥 じぶんだけの えいご アプリ\\nスピーキングの さいてんは インターネットが あると せいかく", zh:"啾啾英语 🐥 属于你的英语学习应用\\n有网络时口语评分更准确", es:"Piyak English 🐥 tu propia app de inglés\\nLa nota de habla es más precisa con internet", fr:"Piyak English 🐥 ton appli d'anglais à toi\\nLa note d'oral est plus précise avec internet", de:"Piyak English 🐥 deine eigene Englisch-App\\nSprechbewertung ist mit Internet genauer", pt:"Piyak English 🐥 seu app de inglês\\nA nota de fala é mais precisa com internet", ru:"Piyak English 🐥 твоё приложение для английского\\nОценка речи точнее с интернетом", vi:"Piyak English 🐥 ứng dụng tiếng Anh của riêng bạn\\nChấm nói chính xác hơn khi có mạng", th:"Piyak English 🐥 แอปเรียนอังกฤษของคุณ\\nการให้คะแนนพูดแม่นยำขึ้นเมื่อมีเน็ต", in:"Piyak English 🐥 aplikasi belajar Inggrismu\\nPenilaian bicara lebih akurat dengan internet" },

// ---------- 레이아웃: 알파벳·쓰기 ----------
ly_alpha_write: { ko:"✏️ 알파벳 쓰기", en:"✏️ Alphabet writing", ja:"✏️ アルファベットを かく", zh:"✏️ 字母书写", es:"✏️ Escribir el alfabeto", fr:"✏️ Écrire l'alphabet", de:"✏️ Alphabet schreiben", pt:"✏️ Escrever o alfabeto", ru:"✏️ Письмо алфавита", vi:"✏️ Viết bảng chữ cái", th:"✏️ หัดเขียนตัวอักษร", in:"✏️ Menulis alfabet" },
ly_alpha_full: { ko:"알파벳 쓰기 (ABC)", en:"Alphabet writing (ABC)", ja:"アルファベットを かく (ABC)", zh:"字母书写 (ABC)", es:"Escribir el alfabeto (ABC)", fr:"Écrire l'alphabet (ABC)", de:"Alphabet schreiben (ABC)", pt:"Escrever o alfabeto (ABC)", ru:"Письмо алфавита (ABC)", vi:"Viết bảng chữ cái (ABC)", th:"หัดเขียนตัวอักษร (ABC)", in:"Menulis alfabet (ABC)" },
ly_alpha_sub2: { ko:"손가락·펜으로 A부터 Z까지 따라 써요", en:"Trace A to Z with your finger or a pen", ja:"ゆびや ペンで AからZまで なぞろう", zh:"用手指或笔从A描到Z", es:"Traza de la A a la Z con el dedo o un lápiz", fr:"Trace de A à Z au doigt ou au stylo", de:"Fahre A bis Z mit Finger oder Stift nach", pt:"Trace de A a Z com o dedo ou caneta", ru:"Обводи от A до Z пальцем или ручкой", vi:"Tô từ A đến Z bằng ngón tay hoặc bút", th:"ลากตาม A ถึง Z ด้วยนิ้วหรือปากกา", in:"Jiplak A sampai Z dengan jari atau pena" },
ly_upper: { ko:"대문자 ABC", en:"Uppercase ABC", ja:"おおもじ ABC", zh:"大写 ABC", es:"Mayúsculas ABC", fr:"Majuscules ABC", de:"Großbuchstaben ABC", pt:"Maiúsculas ABC", ru:"Заглавные ABC", vi:"Chữ hoa ABC", th:"ตัวพิมพ์ใหญ่ ABC", in:"Huruf besar ABC" },
ly_lower: { ko:"소문자 abc", en:"Lowercase abc", ja:"こもじ abc", zh:"小写 abc", es:"Minúsculas abc", fr:"Minuscules abc", de:"Kleinbuchstaben abc", pt:"Minúsculas abc", ru:"Строчные abc", vi:"Chữ thường abc", th:"ตัวพิมพ์เล็ก abc", in:"Huruf kecil abc" },
ly_how: { ko:"🐥 어떻게 써요?", en:"🐥 How do I write it?", ja:"🐥 どう かくの?", zh:"🐥 怎么写?", es:"🐥 ¿Cómo se escribe?", fr:"🐥 Comment l'écrire ?", de:"🐥 Wie schreibt man das?", pt:"🐥 Como se escreve?", ru:"🐥 Как это пишется?", vi:"🐥 Viết thế nào?", th:"🐥 เขียนยังไงนะ?", in:"🐥 Cara menulisnya?" },
ly_trace_hint: { ko:"초록 ① 부터 길을 따라 그려 보세요!", en:"Start at green ① and follow the path!", ja:"みどりの ① から みちを なぞってね!", zh:"从绿色①开始沿着路径画!", es:"¡Empieza en el ① verde y sigue el camino!", fr:"Pars du ① vert et suis le chemin !", de:"Starte beim grünen ① und folge dem Weg!", pt:"Comece no ① verde e siga o caminho!", ru:"Начни с зелёной ① и веди по линии!", vi:"Bắt đầu từ ① xanh và vẽ theo đường!", th:"เริ่มที่ ① สีเขียวแล้วลากตามเส้น!", in:"Mulai dari ① hijau dan ikuti jalurnya!" },
ly_clear2: { ko:"↻ 지우기", en:"↻ Clear", ja:"↻ けす", zh:"↻ 清除", es:"↻ Borrar", fr:"↻ Effacer", de:"↻ Löschen", pt:"↻ Limpar", ru:"↻ Стереть", vi:"↻ Xóa", th:"↻ ล้าง", in:"↻ Hapus" },
ly_once_more: { ko:"🔁 한 번 더!", en:"🔁 One more!", ja:"🔁 もういっかい!", zh:"🔁 再来一次!", es:"🔁 ¡Otra vez!", fr:"🔁 Encore une fois !", de:"🔁 Noch mal!", pt:"🔁 Mais uma!", ru:"🔁 Ещё раз!", vi:"🔁 Một lần nữa!", th:"🔁 อีกครั้ง!", in:"🔁 Sekali lagi!" },
ly_free_move: { ko:"🔓 자유 이동 모드", en:"🔓 Free move mode", ja:"🔓 じゆうに うごかす モード", zh:"🔓 自由移动模式", es:"🔓 Modo libre", fr:"🔓 Mode libre", de:"🔓 Freier Modus", pt:"🔓 Modo livre", ru:"🔓 Свободный режим", vi:"🔓 Chế độ tự do", th:"🔓 โหมดอิสระ", in:"🔓 Mode bebas" },
ly_done_praise: { ko:"잘했어요!", en:"Great job!", ja:"よく できました!", zh:"做得好!", es:"¡Muy bien!", fr:"Bravo !", de:"Gut gemacht!", pt:"Muito bem!", ru:"Молодец!", vi:"Giỏi lắm!", th:"เก่งมาก!", in:"Kerja bagus!" },
ly_difficulty: { ko:"난이도", en:"Difficulty", ja:"むずかしさ", zh:"难度", es:"Dificultad", fr:"Difficulté", de:"Schwierigkeit", pt:"Dificuldade", ru:"Сложность", vi:"Độ khó", th:"ความยาก", in:"Tingkat kesulitan" },
ly_easy: { ko:"쉬움", en:"Easy", ja:"かんたん", zh:"简单", es:"Fácil", fr:"Facile", de:"Leicht", pt:"Fácil", ru:"Легко", vi:"Dễ", th:"ง่าย", in:"Mudah" },
ly_hard: { ko:"어려움", en:"Hard", ja:"むずかしい", zh:"困难", es:"Difícil", fr:"Difficile", de:"Schwer", pt:"Difícil", ru:"Сложно", vi:"Khó", th:"ยาก", in:"Sulit" },
ly_next: { ko:"다음 ▶", en:"Next ▶", ja:"つぎへ ▶", zh:"下一个 ▶", es:"Siguiente ▶", fr:"Suivant ▶", de:"Weiter ▶", pt:"Próximo ▶", ru:"Дальше ▶", vi:"Tiếp ▶", th:"ถัดไป ▶", in:"Berikutnya ▶" },
ly_stop: { ko:"그만하기", en:"Stop", ja:"やめる", zh:"结束", es:"Terminar", fr:"Arrêter", de:"Beenden", pt:"Parar", ru:"Закончить", vi:"Dừng", th:"หยุด", in:"Berhenti" },

// ---------- 레이아웃: 문제 화면 ----------
ly_my_answer: { ko:"내 답:", en:"My answer:", ja:"わたしの こたえ:", zh:"我的答案:", es:"Mi respuesta:", fr:"Ma réponse :", de:"Meine Antwort:", pt:"Minha resposta:", ru:"Мой ответ:", vi:"Câu trả lời của tôi:", th:"คำตอบของฉัน:", in:"Jawabanku:" },
ly_type_hint: { ko:"영어로 입력하세요", en:"Type in English", ja:"えいごで にゅうりょくしてね", zh:"请用英语输入", es:"Escribe en inglés", fr:"Écris en anglais", de:"Auf Englisch eingeben", pt:"Digite em inglês", ru:"Введи по-английски", vi:"Nhập bằng tiếng Anh", th:"พิมพ์เป็นภาษาอังกฤษ", in:"Ketik dalam bahasa Inggris" },
ly_speak_btn: { ko:"🎤 말하기", en:"🎤 Speak", ja:"🎤 はなす", zh:"🎤 说话", es:"🎤 Hablar", fr:"🎤 Parler", de:"🎤 Sprechen", pt:"🎤 Falar", ru:"🎤 Говорить", vi:"🎤 Nói", th:"🎤 พูด", in:"🎤 Bicara" },
ly_listen_btn: { ko:"🔊 듣기", en:"🔊 Listen", ja:"🔊 きく", zh:"🔊 听", es:"🔊 Escuchar", fr:"🔊 Écouter", de:"🔊 Anhören", pt:"🔊 Ouvir", ru:"🔊 Слушать", vi:"🔊 Nghe", th:"🔊 ฟัง", in:"🔊 Dengarkan" },
ly_skip_speak: { ko:"지금은 말할 수 없어요 (건너뛰기)", en:"I can't speak right now (skip)", ja:"いまは はなせない (スキップ)", zh:"现在不方便说话 (跳过)", es:"No puedo hablar ahora (saltar)", fr:"Je ne peux pas parler (passer)", de:"Kann gerade nicht sprechen (überspringen)", pt:"Não posso falar agora (pular)", ru:"Сейчас не могу говорить (пропустить)", vi:"Bây giờ không nói được (bỏ qua)", th:"ตอนนี้พูดไม่ได้ (ข้าม)", in:"Tidak bisa bicara sekarang (lewati)" },

// ---------- 레이아웃: 트랙·놀이터 ----------
ly_track: { ko:"트랙", en:"Track", ja:"トラック", zh:"轨道", es:"Pista", fr:"Piste", de:"Track", pt:"Trilha", ru:"Трек", vi:"Lộ trình", th:"คอร์ส", in:"Jalur" },
ly_track_free: { ko:"모든 레슨을 순서 상관없이 풀 수 있어요", en:"Play any lesson in any order", ja:"どの レッスンからでも できるよ", zh:"所有课程可以任意顺序学", es:"Haz las lecciones en el orden que quieras", fr:"Fais les leçons dans l'ordre que tu veux", de:"Lektionen in beliebiger Reihenfolge", pt:"Faça as lições em qualquer ordem", ru:"Проходи уроки в любом порядке", vi:"Học bài nào trước cũng được", th:"เรียนบทไหนก่อนก็ได้", in:"Kerjakan pelajaran dalam urutan bebas" },
ly_match_pairs: { ko:"단어와 뜻을 짝지어 주세요", en:"Match each word with its meaning", ja:"たんごと いみを くみあわせてね", zh:"请把单词和意思配对", es:"Empareja cada palabra con su significado", fr:"Associe chaque mot à son sens", de:"Ordne jedem Wort seine Bedeutung zu", pt:"Combine cada palavra com seu significado", ru:"Соедини слова с их значениями", vi:"Ghép từ với nghĩa của nó", th:"จับคู่คำกับความหมาย", in:"Jodohkan kata dengan artinya" },
ly_play_desc: { ko:"손가락으로 만지고 움직이며 노는 게임이에요 🐥", en:"Games you play by touching and moving 🐥", ja:"ゆびで さわって うごかして あそぶ ゲームだよ 🐥", zh:"用手指触摸移动来玩的游戏 🐥", es:"Juegos para tocar y mover con el dedo 🐥", fr:"Des jeux où l'on touche et déplace 🐥", de:"Spiele zum Anfassen und Bewegen 🐥", pt:"Jogos de tocar e mover 🐥", ru:"Игры, где трогаешь и двигаешь 🐥", vi:"Trò chơi chạm và kéo bằng ngón tay 🐥", th:"เกมที่เล่นด้วยการแตะและลาก 🐥", in:"Gim yang dimainkan dengan sentuhan 🐥" },
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
  " * 나머지 화면 문자열 — 자동 생성: node tools/i18n/make_ui_rest.js\n" +
  " * 수학 앱과 원문이 같은 키는 수학 원장에서 베껴 온다 (직접 고치지 말 것).\n" +
  " */\n" +
  "module.exports = {\n\n" +
  "// ---------- 수학 앱에서 베껴 온 키 ----------\n" +
  out.join("\n") + "\n" +
  EXTRA + "\n};\n";
fs.writeFileSync(path.join(__dirname, "ui_rest.js"), body, "utf8");
console.log(`복사 ${out.length}키 + 전용 키 → ui_rest.js`);
