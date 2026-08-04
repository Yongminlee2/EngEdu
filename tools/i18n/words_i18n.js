/**
 * 제목·인자에 박혀 오는 한국어 낱말 사전 (Tpl.word 가 갈아 끼운다).
 * gen_strings.js 가 tpl_words string-array 로 굽는다. 키는 한국어 원문 그대로.
 * (그림 없는 단어 뜻 1,093종은 그림 보기가 대신하므로 여기엔 제목 낱말만 있다.)
 */
module.exports = {

// ---------- 기초 트랙 마을 이름 ----------
"음식 마을": { en:"Food Town", ja:"たべもの むら", zh:"食物村", es:"Villa Comida", fr:"Village Nourriture", de:"Essensdorf", pt:"Vila da Comida", ru:"Городок еды", vi:"Làng đồ ăn", th:"หมู่บ้านอาหาร", in:"Kampung Makanan" },
"학교 마을": { en:"School Town", ja:"がっこう むら", zh:"学校村", es:"Villa Escuela", fr:"Village École", de:"Schuldorf", pt:"Vila da Escola", ru:"Городок школы", vi:"Làng trường học", th:"หมู่บ้านโรงเรียน", in:"Kampung Sekolah" },
"가족과 사람 마을": { en:"Family & People Town", ja:"かぞくと ひと むら", zh:"家人与人村", es:"Villa Familia y Gente", fr:"Village Famille et Gens", de:"Familien- und Menschendorf", pt:"Vila da Família e Pessoas", ru:"Городок семьи и людей", vi:"Làng gia đình và con người", th:"หมู่บ้านครอบครัวและผู้คน", in:"Kampung Keluarga & Orang" },
"몸과 건강 마을": { en:"Body & Health Town", ja:"からだと けんこう むら", zh:"身体与健康村", es:"Villa Cuerpo y Salud", fr:"Village Corps et Santé", de:"Körper- und Gesundheitsdorf", pt:"Vila do Corpo e Saúde", ru:"Городок тела и здоровья", vi:"Làng cơ thể và sức khỏe", th:"หมู่บ้านร่างกายและสุขภาพ", in:"Kampung Tubuh & Kesehatan" },
"색깔과 모양 마을": { en:"Colors & Shapes Town", ja:"いろと かたち むら", zh:"颜色与形状村", es:"Villa Colores y Formas", fr:"Village Couleurs et Formes", de:"Farben- und Formendorf", pt:"Vila das Cores e Formas", ru:"Городок цветов и форм", vi:"Làng màu sắc và hình dạng", th:"หมู่บ้านสีและรูปทรง", in:"Kampung Warna & Bentuk" },
"마음과 행동 마을": { en:"Feelings & Actions Town", ja:"きもちと こうどう むら", zh:"心情与行动村", es:"Villa Emociones y Acciones", fr:"Village Émotions et Actions", de:"Gefühls- und Handlungsdorf", pt:"Vila dos Sentimentos e Ações", ru:"Городок чувств и действий", vi:"Làng cảm xúc và hành động", th:"หมู่บ้านความรู้สึกและการกระทำ", in:"Kampung Perasaan & Tindakan" },
"자연과 날씨 마을": { en:"Nature & Weather Town", ja:"しぜんと てんき むら", zh:"自然与天气村", es:"Villa Naturaleza y Clima", fr:"Village Nature et Météo", de:"Natur- und Wetterdorf", pt:"Vila da Natureza e Clima", ru:"Городок природы и погоды", vi:"Làng thiên nhiên và thời tiết", th:"หมู่บ้านธรรมชาติและอากาศ", in:"Kampung Alam & Cuaca" },
"우리 집 마을": { en:"My Home Town", ja:"おうち むら", zh:"我家村", es:"Villa Mi Casa", fr:"Village Ma Maison", de:"Mein-Zuhause-Dorf", pt:"Vila da Minha Casa", ru:"Городок моего дома", vi:"Làng nhà em", th:"หมู่บ้านบ้านของฉัน", in:"Kampung Rumahku" },
"동물 마을": { en:"Animal Town", ja:"どうぶつ むら", zh:"动物村", es:"Villa Animales", fr:"Village Animaux", de:"Tierdorf", pt:"Vila dos Animais", ru:"Городок животных", vi:"Làng động vật", th:"หมู่บ้านสัตว์", in:"Kampung Hewan" },
"시간과 하루 마을": { en:"Time & Day Town", ja:"じかんと いちにち むら", zh:"时间与一天村", es:"Villa Tiempo y Día", fr:"Village Temps et Journée", de:"Zeit- und Tagesdorf", pt:"Vila do Tempo e do Dia", ru:"Городок времени и дня", vi:"Làng thời gian và ngày", th:"หมู่บ้านเวลาและวัน", in:"Kampung Waktu & Hari" },
"놀이와 운동 마을": { en:"Play & Sports Town", ja:"あそびと うんどう むら", zh:"游戏与运动村", es:"Villa Juegos y Deportes", fr:"Village Jeux et Sports", de:"Spiel- und Sportdorf", pt:"Vila dos Jogos e Esportes", ru:"Городок игр и спорта", vi:"Làng vui chơi và thể thao", th:"หมู่บ้านการเล่นและกีฬา", in:"Kampung Main & Olahraga" },
"마을과 탈것 마을": { en:"Town & Vehicles Town", ja:"まちと のりもの むら", zh:"城镇与交通工具村", es:"Villa Ciudad y Vehículos", fr:"Village Ville et Véhicules", de:"Stadt- und Fahrzeugdorf", pt:"Vila da Cidade e Veículos", ru:"Городок города и транспорта", vi:"Làng phố xá và xe cộ", th:"หมู่บ้านเมืองและยานพาหนะ", in:"Kampung Kota & Kendaraan" },
"옷과 물건 마을": { en:"Clothes & Things Town", ja:"ふくと もの むら", zh:"衣服与物品村", es:"Villa Ropa y Objetos", fr:"Village Vêtements et Objets", de:"Kleider- und Sachendorf", pt:"Vila das Roupas e Objetos", ru:"Городок одежды и вещей", vi:"Làng quần áo và đồ vật", th:"หมู่บ้านเสื้อผ้าและสิ่งของ", in:"Kampung Baju & Barang" },

// ---------- 기초 트랙 어휘·특수 유닛 ----------
"낱말 탐험": { en:"Word Expedition", ja:"たんご たんけん", zh:"单词探险", es:"Expedición de palabras", fr:"Expédition des mots", de:"Wort-Expedition", pt:"Expedição de palavras", ru:"Экспедиция слов", vi:"Thám hiểm từ vựng", th:"สำรวจคำศัพท์", in:"Ekspedisi kata" },
"어휘 산책": { en:"Vocabulary Walk", ja:"ごい さんぽ", zh:"词汇散步", es:"Paseo de vocabulario", fr:"Balade de vocabulaire", de:"Wortschatz-Spaziergang", pt:"Passeio de vocabulário", ru:"Прогулка по лексике", vi:"Dạo bước từ vựng", th:"เดินเล่นคำศัพท์", in:"Jalan-jalan kosakata" },
"낱말 캠프": { en:"Word Camp", ja:"たんご キャンプ", zh:"单词营", es:"Campamento de palabras", fr:"Camp des mots", de:"Wort-Camp", pt:"Acampamento de palavras", ru:"Лагерь слов", vi:"Trại từ vựng", th:"แคมป์คำศัพท์", in:"Kamp kata" },
"어휘 정원": { en:"Vocabulary Garden", ja:"ごい ガーデン", zh:"词汇花园", es:"Jardín de vocabulario", fr:"Jardin de vocabulaire", de:"Wortschatz-Garten", pt:"Jardim de vocabulário", ru:"Сад лексики", vi:"Vườn từ vựng", th:"สวนคำศัพท์", in:"Taman kosakata" },
"단어 열기구": { en:"Word Balloon Ride", ja:"たんご ききゅう", zh:"单词热气球", es:"Globo de palabras", fr:"Montgolfière des mots", de:"Wort-Heißluftballon", pt:"Balão de palavras", ru:"Воздушный шар слов", vi:"Khinh khí cầu từ vựng", th:"บอลลูนคำศัพท์", in:"Balon udara kata" },
"단어 여행": { en:"Word Journey", ja:"たんご りょこう", zh:"单词旅行", es:"Viaje de palabras", fr:"Voyage des mots", de:"Wortreise", pt:"Viagem de palavras", ru:"Путешествие слов", vi:"Hành trình từ vựng", th:"ทริปคำศัพท์", in:"Perjalanan kata" },
"단어 보물찾기": { en:"Word Treasure Hunt", ja:"たんご たからさがし", zh:"单词寻宝", es:"Búsqueda del tesoro de palabras", fr:"Chasse au trésor des mots", de:"Wort-Schatzsuche", pt:"Caça ao tesouro de palavras", ru:"Охота за словами", vi:"Săn kho báu từ vựng", th:"ล่าสมบัติคำศัพท์", in:"Berburu harta kata" },
"낱말 등대": { en:"Word Lighthouse", ja:"たんご とうだい", zh:"单词灯塔", es:"Faro de palabras", fr:"Phare des mots", de:"Wort-Leuchtturm", pt:"Farol de palavras", ru:"Маяк слов", vi:"Hải đăng từ vựng", th:"ประภาคารคำศัพท์", in:"Mercusuar kata" },
"단어마을": { en:"Word Town", ja:"たんご むら", zh:"单词村", es:"Villa de palabras", fr:"Village des mots", de:"Wortdorf", pt:"Vila de palavras", ru:"Городок слов", vi:"Làng từ vựng", th:"หมู่บ้านคำศัพท์", in:"Kampung kata" },
"문법 클리닉": { en:"Grammar Clinic", ja:"ぶんぽう クリニック", zh:"语法诊所", es:"Clínica de gramática", fr:"Clinique de grammaire", de:"Grammatik-Klinik", pt:"Clínica de gramática", ru:"Клиника грамматики", vi:"Phòng khám ngữ pháp", th:"คลินิกไวยากรณ์", in:"Klinik tata bahasa" },
"문장 공방": { en:"Sentence Workshop", ja:"ぶんしょう こうぼう", zh:"句子工坊", es:"Taller de frases", fr:"Atelier de phrases", de:"Satz-Werkstatt", pt:"Oficina de frases", ru:"Мастерская предложений", vi:"Xưởng câu", th:"เวิร์กช็อปประโยค", in:"Bengkel kalimat" },

// ---------- 학년 띠 ----------
"초등 1~2학년": { en:"Grades 1–2", ja:"しょう1~2ねん", zh:"小学1~2年级", es:"1º–2º de primaria", fr:"Années 1–2", de:"Klasse 1–2", pt:"1º–2º ano", ru:"1–2 класс", vi:"Lớp 1–2", th:"ป.1–2", in:"Kelas 1–2" },
"초등 3~4학년": { en:"Grades 3–4", ja:"しょう3~4ねん", zh:"小学3~4年级", es:"3º–4º de primaria", fr:"Années 3–4", de:"Klasse 3–4", pt:"3º–4º ano", ru:"3–4 класс", vi:"Lớp 3–4", th:"ป.3–4", in:"Kelas 3–4" },
"초등 5~6학년": { en:"Grades 5–6", ja:"しょう5~6ねん", zh:"小学5~6年级", es:"5º–6º de primaria", fr:"Années 5–6", de:"Klasse 5–6", pt:"5º–6º ano", ru:"5–6 класс", vi:"Lớp 5–6", th:"ป.5–6", in:"Kelas 5–6" },
"중학 1학년": { en:"Middle school 1", ja:"ちゅう1", zh:"初一", es:"Secundaria 1", fr:"Collège 1", de:"Mittelstufe 1", pt:"Ginásio 1", ru:"Средняя школа 1", vi:"Lớp 7", th:"ม.1", in:"SMP 1" },
"중학 2학년": { en:"Middle school 2", ja:"ちゅう2", zh:"初二", es:"Secundaria 2", fr:"Collège 2", de:"Mittelstufe 2", pt:"Ginásio 2", ru:"Средняя школа 2", vi:"Lớp 8", th:"ม.2", in:"SMP 2" },
"중학 3학년": { en:"Middle school 3", ja:"ちゅう3", zh:"初三", es:"Secundaria 3", fr:"Collège 3", de:"Mittelstufe 3", pt:"Ginásio 3", ru:"Средняя школа 3", vi:"Lớp 9", th:"ม.3", in:"SMP 3" },
"고등 1학년": { en:"High school 1", ja:"こう1", zh:"高一", es:"Bachillerato 1", fr:"Lycée 1", de:"Oberstufe 1", pt:"Colegial 1", ru:"Старшая школа 1", vi:"Lớp 10", th:"ม.4", in:"SMA 1" },
"고등 2~3학년": { en:"High school 2–3", ja:"こう2~3", zh:"高二~高三", es:"Bachillerato 2–3", fr:"Lycée 2–3", de:"Oberstufe 2–3", pt:"Colegial 2–3", ru:"Старшая школа 2–3", vi:"Lớp 11–12", th:"ม.5–6", in:"SMA 2–3" },
"성인·비즈니스": { en:"Adult · Business", ja:"おとな · ビジネス", zh:"成人·商务", es:"Adulto · Negocios", fr:"Adulte · Affaires", de:"Erwachsene · Business", pt:"Adulto · Negócios", ru:"Взрослый · Бизнес", vi:"Người lớn · Thương mại", th:"ผู้ใหญ่ · ธุรกิจ", in:"Dewasa · Bisnis" },
"고급·학술": { en:"Advanced · Academic", ja:"じょうきゅう · アカデミック", zh:"高级·学术", es:"Avanzado · Académico", fr:"Avancé · Académique", de:"Fortgeschritten · Akademisch", pt:"Avançado · Acadêmico", ru:"Продвинутый · Академический", vi:"Nâng cao · Học thuật", th:"ระดับสูง · วิชาการ", in:"Mahir · Akademik" },

// ---------- 초등영어 코스 유닛·레슨 이름 ----------
"알파벳 찾기 (대문자)": { en:"Find the Letter (Uppercase)", ja:"アルファベットさがし (おおもじ)", zh:"找字母 (大写)", es:"Busca la letra (mayúsculas)", fr:"Trouve la lettre (majuscules)", de:"Buchstaben finden (groß)", pt:"Ache a letra (maiúsculas)", ru:"Найди букву (заглавные)", vi:"Tìm chữ cái (in hoa)", th:"หาตัวอักษร (พิมพ์ใหญ่)", in:"Cari huruf (kapital)" },
"대문자와 소문자 짝꿍": { en:"Uppercase–Lowercase Pairs", ja:"おおもじと こもじの ペア", zh:"大小写配对", es:"Parejas mayúscula–minúscula", fr:"Paires majuscule–minuscule", de:"Groß-Klein-Paare", pt:"Pares maiúscula–minúscula", ru:"Пары заглавных и строчных", vi:"Cặp chữ hoa–thường", th:"จับคู่พิมพ์ใหญ่–เล็ก", in:"Pasangan huruf besar–kecil" },
"알파벳 소리 듣기": { en:"Letter Sounds", ja:"アルファベットの おと", zh:"听字母音", es:"Sonidos de las letras", fr:"Sons des lettres", de:"Buchstabenlaute", pt:"Sons das letras", ru:"Звуки букв", vi:"Âm chữ cái", th:"ฟังเสียงตัวอักษร", in:"Bunyi huruf" },
"첫소리 찾기 (파닉스)": { en:"First Sounds (Phonics)", ja:"はじめの おと (フォニックス)", zh:"找首音 (自然拼读)", es:"Primer sonido (fonética)", fr:"Premier son (phonétique)", de:"Anlaute (Phonics)", pt:"Primeiro som (fonética)", ru:"Первый звук (фоника)", vi:"Âm đầu (phonics)", th:"เสียงต้น (โฟนิกส์)", in:"Bunyi awal (fonik)" },
"가운데 소리 (모음)": { en:"Middle Sounds (Vowels)", ja:"まんなかの おと (ぼいん)", zh:"中间音 (元音)", es:"Sonido medio (vocales)", fr:"Son du milieu (voyelles)", de:"Mittellaute (Vokale)", pt:"Som do meio (vogais)", ru:"Средний звук (гласные)", vi:"Âm giữa (nguyên âm)", th:"เสียงกลาง (สระ)", in:"Bunyi tengah (vokal)" },
"그림 보고 단어 찾기": { en:"Match Picture to Word", ja:"えを みて たんごを さがす", zh:"看图找单词", es:"Une dibujo y palabra", fr:"Associe image et mot", de:"Bild dem Wort zuordnen", pt:"Ligue figura e palavra", ru:"Картинка и слово", vi:"Nhìn hình tìm từ", th:"ดูรูปหาคำ", in:"Cocokkan gambar dan kata" },
"단어 뜻 맞히기": { en:"Guess the Meaning", ja:"たんごの いみ あてる", zh:"猜单词意思", es:"Adivina el significado", fr:"Devine le sens", de:"Bedeutung erraten", pt:"Adivinhe o significado", ru:"Угадай значение", vi:"Đoán nghĩa từ", th:"ทายความหมายคำ", in:"Tebak arti kata" },
"듣고 그림 찾기": { en:"Listen and Find the Picture", ja:"きいて えを さがす", zh:"听音找图", es:"Escucha y busca el dibujo", fr:"Écoute et trouve l'image", de:"Hören und Bild finden", pt:"Ouça e ache a figura", ru:"Слушай и найди картинку", vi:"Nghe và tìm hình", th:"ฟังแล้วหารูป", in:"Dengar dan cari gambar" },
"자주 나오는 낱말": { en:"Sight Words", ja:"よく でる たんご", zh:"常见词", es:"Palabras frecuentes", fr:"Mots fréquents", de:"Häufige Wörter", pt:"Palavras frequentes", ru:"Частые слова", vi:"Từ thường gặp", th:"คำที่พบบ่อย", in:"Kata yang sering muncul" },
"단어 써 보기": { en:"Write the Word", ja:"たんごを かいてみる", zh:"写单词", es:"Escribe la palabra", fr:"Écris le mot", de:"Wort schreiben", pt:"Escreva a palavra", ru:"Напиши слово", vi:"Viết từ", th:"ลองเขียนคำ", in:"Tulis katanya" },
"문장 읽기": { en:"Read Sentences", ja:"ぶんしょうを よむ", zh:"读句子", es:"Lee frases", fr:"Lis des phrases", de:"Sätze lesen", pt:"Leia frases", ru:"Читай предложения", vi:"Đọc câu", th:"อ่านประโยค", in:"Baca kalimat" },
"따라 말하기": { en:"Repeat After Me", ja:"まねして いう", zh:"跟读", es:"Repite conmigo", fr:"Répète après moi", de:"Nachsprechen", pt:"Repita comigo", ru:"Повторяй за мной", vi:"Nói theo", th:"พูดตาม", in:"Ikuti ucapannya" },
"문장 받아쓰기": { en:"Sentence Dictation", ja:"ぶんしょう かきとり", zh:"句子听写", es:"Dictado de frases", fr:"Dictée de phrases", de:"Satzdiktat", pt:"Ditado de frases", ru:"Диктант предложений", vi:"Chính tả câu", th:"เขียนตามคำบอกประโยค", in:"Dikte kalimat" },

// ---------- 일상·여행 장면 이름 ("%s · 표현/말하기") ----------
"첫 만남": { en:"First Meeting", ja:"はじめての であい", zh:"初次见面", es:"Primer encuentro", fr:"Première rencontre", de:"Erstes Treffen", pt:"Primeiro encontro", ru:"Первая встреча", vi:"Lần đầu gặp", th:"พบกันครั้งแรก", in:"Pertemuan pertama" },
"안부 묻기": { en:"Asking How You Are", ja:"あんぴを きく", zh:"问候近况", es:"Preguntar cómo estás", fr:"Prendre des nouvelles", de:"Nach dem Befinden fragen", pt:"Perguntar como vai", ru:"Спросить, как дела", vi:"Hỏi thăm", th:"ถามสารทุกข์", in:"Menanyakan kabar" },
"자기소개하기": { en:"Introducing Yourself", ja:"じこしょうかい", zh:"自我介绍", es:"Presentarse", fr:"Se présenter", de:"Sich vorstellen", pt:"Apresentar-se", ru:"Рассказать о себе", vi:"Tự giới thiệu", th:"แนะนำตัวเอง", in:"Memperkenalkan diri" },
"주문하기": { en:"Ordering", ja:"ちゅうもんする", zh:"点餐", es:"Pedir comida", fr:"Commander", de:"Bestellen", pt:"Fazer o pedido", ru:"Сделать заказ", vi:"Gọi món", th:"สั่งอาหาร", in:"Memesan" },
"계산하기": { en:"Paying the Bill", ja:"おかいけい", zh:"结账", es:"Pagar la cuenta", fr:"Payer l'addition", de:"Bezahlen", pt:"Pagar a conta", ru:"Оплатить счёт", vi:"Thanh toán", th:"จ่ายเงิน", in:"Membayar" },
"특별 요청": { en:"Special Requests", ja:"とくべつな おねがい", zh:"特殊要求", es:"Peticiones especiales", fr:"Demandes spéciales", de:"Sonderwünsche", pt:"Pedidos especiais", ru:"Особые просьбы", vi:"Yêu cầu đặc biệt", th:"คำขอพิเศษ", in:"Permintaan khusus" },
"옷 사기": { en:"Buying Clothes", ja:"ふくを かう", zh:"买衣服", es:"Comprar ropa", fr:"Acheter des vêtements", de:"Kleidung kaufen", pt:"Comprar roupas", ru:"Покупка одежды", vi:"Mua quần áo", th:"ซื้อเสื้อผ้า", in:"Membeli baju" },
"환불하기": { en:"Getting a Refund", ja:"へんぴん · はらいもどし", zh:"退款", es:"Pedir un reembolso", fr:"Se faire rembourser", de:"Geld zurückbekommen", pt:"Pedir reembolso", ru:"Вернуть деньги", vi:"Hoàn tiền", th:"ขอคืนเงิน", in:"Minta pengembalian dana" },
"가격 흥정": { en:"Bargaining", ja:"ねだん こうしょう", zh:"讨价还价", es:"Regatear", fr:"Négocier le prix", de:"Handeln", pt:"Pechinchar", ru:"Торговаться", vi:"Mặc cả", th:"ต่อราคา", in:"Menawar" },
"길 묻기": { en:"Asking for Directions", ja:"みちを きく", zh:"问路", es:"Preguntar el camino", fr:"Demander son chemin", de:"Nach dem Weg fragen", pt:"Pedir informações", ru:"Спросить дорогу", vi:"Hỏi đường", th:"ถามทาง", in:"Bertanya arah" },
"지하철 타기": { en:"Taking the Subway", ja:"ちかてつに のる", zh:"坐地铁", es:"Tomar el metro", fr:"Prendre le métro", de:"U-Bahn fahren", pt:"Pegar o metrô", ru:"Поездка на метро", vi:"Đi tàu điện ngầm", th:"ขึ้นรถไฟใต้ดิน", in:"Naik kereta bawah tanah" },
"길을 잃었을 때": { en:"When You're Lost", ja:"みちに まよったら", zh:"迷路时", es:"Cuando te pierdes", fr:"Quand on est perdu", de:"Wenn man sich verirrt", pt:"Quando você se perde", ru:"Если заблудился", vi:"Khi bị lạc", th:"เมื่อหลงทาง", in:"Saat tersesat" },
"체크인": { en:"Check-in", ja:"チェックイン", zh:"值机", es:"Facturación", fr:"Enregistrement", de:"Check-in", pt:"Check-in", ru:"Регистрация", vi:"Check-in", th:"เช็กอิน", in:"Check-in" },
"입국 심사": { en:"Immigration", ja:"にゅうこく しんさ", zh:"入境审查", es:"Control de inmigración", fr:"Contrôle d'immigration", de:"Einreisekontrolle", pt:"Imigração", ru:"Паспортный контроль", vi:"Nhập cảnh", th:"ตรวจคนเข้าเมือง", in:"Imigrasi" },
"기내에서": { en:"On the Plane", ja:"きないで", zh:"在机上", es:"En el avión", fr:"Dans l'avion", de:"Im Flugzeug", pt:"No avião", ru:"В самолёте", vi:"Trên máy bay", th:"บนเครื่องบิน", in:"Di pesawat" },
"체크인하기": { en:"Checking In", ja:"チェックインする", zh:"办理入住", es:"Registrarse", fr:"S'enregistrer", de:"Einchecken", pt:"Fazer check-in", ru:"Заселение", vi:"Nhận phòng", th:"เช็กอินที่พัก", in:"Check-in hotel" },
"문제 해결": { en:"Solving Problems", ja:"トラブル かいけつ", zh:"解决问题", es:"Resolver problemas", fr:"Résoudre un problème", de:"Probleme lösen", pt:"Resolver problemas", ru:"Решение проблем", vi:"Xử lý sự cố", th:"แก้ปัญหา", in:"Menyelesaikan masalah" },
"체크아웃": { en:"Check-out", ja:"チェックアウト", zh:"退房", es:"Salida del hotel", fr:"Départ de l'hôtel", de:"Check-out", pt:"Check-out", ru:"Выселение", vi:"Trả phòng", th:"เช็กเอาต์", in:"Check-out" },
"택시 타기": { en:"Taking a Taxi", ja:"タクシーに のる", zh:"打车", es:"Tomar un taxi", fr:"Prendre un taxi", de:"Taxi fahren", pt:"Pegar um táxi", ru:"Поездка на такси", vi:"Đi taxi", th:"นั่งแท็กซี่", in:"Naik taksi" },
"버스 묻기": { en:"Asking About Buses", ja:"バスを きく", zh:"问公交", es:"Preguntar por el bus", fr:"Se renseigner sur le bus", de:"Nach dem Bus fragen", pt:"Perguntar sobre o ônibus", ru:"Спросить про автобус", vi:"Hỏi xe buýt", th:"ถามเรื่องรถเมล์", in:"Bertanya soal bus" },
"렌터카 빌리기": { en:"Renting a Car", ja:"レンタカーを かりる", zh:"租车", es:"Alquilar un coche", fr:"Louer une voiture", de:"Auto mieten", pt:"Alugar um carro", ru:"Аренда машины", vi:"Thuê xe", th:"เช่ารถ", in:"Menyewa mobil" },
"아플 때": { en:"When You're Sick", ja:"ぐあいが わるいとき", zh:"生病时", es:"Cuando estás enfermo", fr:"Quand on est malade", de:"Wenn man krank ist", pt:"Quando você adoece", ru:"Если заболел", vi:"Khi bị ốm", th:"เมื่อป่วย", in:"Saat sakit" },
"분실 신고": { en:"Reporting Lost Items", ja:"ふんしつ とどけ", zh:"挂失", es:"Denunciar una pérdida", fr:"Déclarer une perte", de:"Verlust melden", pt:"Registrar perda", ru:"Заявить о пропаже", vi:"Báo mất đồ", th:"แจ้งของหาย", in:"Melapor kehilangan" },
"약국에서": { en:"At the Pharmacy", ja:"やっきょくで", zh:"在药店", es:"En la farmacia", fr:"À la pharmacie", de:"In der Apotheke", pt:"Na farmácia", ru:"В аптеке", vi:"Ở hiệu thuốc", th:"ที่ร้านขายยา", in:"Di apotek" },
"날씨 이야기": { en:"Talking About Weather", ja:"てんきの はなし", zh:"聊天气", es:"Hablar del clima", fr:"Parler de la météo", de:"Übers Wetter reden", pt:"Falar do tempo", ru:"Разговор о погоде", vi:"Chuyện thời tiết", th:"คุยเรื่องอากาศ", in:"Bicara soal cuaca" },
"취미 이야기": { en:"Talking About Hobbies", ja:"しゅみの はなし", zh:"聊爱好", es:"Hablar de aficiones", fr:"Parler de ses loisirs", de:"Über Hobbys reden", pt:"Falar de hobbies", ru:"Разговор о хобби", vi:"Chuyện sở thích", th:"คุยเรื่องงานอดิเรก", in:"Bicara soal hobi" },
"주말 계획": { en:"Weekend Plans", ja:"しゅうまつの よてい", zh:"周末计划", es:"Planes del fin de semana", fr:"Projets du week-end", de:"Wochenendpläne", pt:"Planos do fim de semana", ru:"Планы на выходные", vi:"Kế hoạch cuối tuần", th:"แผนสุดสัปดาห์", in:"Rencana akhir pekan" },

};

// 단어 뜻 사전(자동 배치 번역)은 words_auto/ 폴더에 파일로 나눠 둔다 — 자동 병합
const fs = require("fs");
const path = require("path");
const dir = path.join(__dirname, "words_auto");
if (fs.existsSync(dir)) {
  for (const f of fs.readdirSync(dir).sort()) {
    if (f.endsWith(".js")) Object.assign(module.exports, require(path.join(dir, f)));
  }
}
