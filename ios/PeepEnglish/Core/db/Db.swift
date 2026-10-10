import Foundation

// 스키마를 바꾸는 마이그레이션(onUpgrade 의 oldV < N)을 추가하면 **DB_VERSION 도 N 으로 올려야 한다.**
// (안드로이드 v2.0 에서 버전을 안 올려 업그레이드된 폰에서만 알파벳 화면이 죽은 적이 있다)
// Kotlin Long → Int, Pair → (first:, second:) 튜플, Triple → (first:, second:, third:) 튜플.
final class Db: SQLiteOpenHelper {

    /// 안드로이드 Db.kt 의 버전과 같아야 한다 (DbMigrationTests 가 대조한다)
    static let DB_VERSION = 6

    private static var inst: Db? = nil

    static func get(_ ctx: Context) -> Db {
        if let d = inst { return d }
        let d = Db(ctx.applicationContext)
        inst = d
        return d
    }

    static func today() -> Int { LocalDate.now().toEpochDay() }

    private init(_ ctx: Context) {
        super.init(ctx, "piyak.db", nil, Db.DB_VERSION)
    }

    override func onCreate(_ db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE progress(lesson_id TEXT PRIMARY KEY, track TEXT, stars INTEGER, best_acc REAL, completed_at INTEGER)")
        db.execSQL("CREATE TABLE wrongs(qid TEXT PRIMARY KEY, lesson_id TEXT, track TEXT, wrong INTEGER DEFAULT 1, ok_streak INTEGER DEFAULT 0, cleared INTEGER DEFAULT 0, last_at INTEGER)")
        db.execSQL("CREATE TABLE days(day INTEGER PRIMARY KEY)")
        db.execSQL("CREATE TABLE badges(id TEXT PRIMARY KEY, at INTEGER)")
        db.execSQL("CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)")
        db.execSQL("CREATE TABLE skills(skill TEXT PRIMARY KEY, attempts INTEGER DEFAULT 0, correct INTEGER DEFAULT 0)")
        db.execSQL("CREATE TABLE letters(key TEXT PRIMARY KEY, stars INTEGER DEFAULT 0, writes INTEGER DEFAULT 0, at INTEGER)")
        createWalletTables(db)
    }

    private func createWalletTables(_ db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS wallet_log(" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER, kind TEXT, amount INTEGER, note TEXT)"
        )
        db.execSQL("CREATE TABLE IF NOT EXISTS inventory(item TEXT PRIMARY KEY, count INTEGER DEFAULT 0)")
    }

    override func onUpgrade(_ db: SQLiteDatabase, _ oldV: Int, _ newV: Int) {
        if oldV < 2 {
            db.execSQL("CREATE TABLE IF NOT EXISTS skills(skill TEXT PRIMARY KEY, attempts INTEGER DEFAULT 0, correct INTEGER DEFAULT 0)")
        }
        if oldV < 3 {
            db.execSQL("CREATE TABLE IF NOT EXISTS letters(key TEXT PRIMARY KEY, stars INTEGER DEFAULT 0, at INTEGER)")
        }
        if oldV < 4 { createWalletTables(db) }
        if oldV < 6 {
            // 알파벳을 여러 번 쓸 수 있게 되면서 쓴 횟수를 센다
            db.tryExecSQL("ALTER TABLE letters ADD COLUMN writes INTEGER DEFAULT 0")
            // 이미 완성한 글자는 1회 쓴 것으로 인정
            db.execSQL("UPDATE letters SET writes = 1 WHERE stars > 0 AND writes = 0")
        }
        // 용돈 기능이 생기기 전에 이미 해 둔 공부에도 소급해서 보상한다
        if oldV < 5 { grantLegacyRewards(db) }
    }

    private func grantLegacyRewards(_ db: SQLiteDatabase) {
        var total = 0
        var letters = 0
        var lessons = 0
        db.rawQuery("SELECT COUNT(*) FROM letters WHERE stars > 0", nil).use {
            if $0.moveToFirst() { letters = $0.getInt(0) }
        }
        db.rawQuery("SELECT COUNT(*) FROM progress", nil).use {
            if $0.moveToFirst() { lessons = $0.getInt(0) }
        }
        total += letters * Wallet.PER_LETTER
        // 지난 레슨은 문제별 기록이 없으니 한 판당 100원으로 셈한다
        total += lessons * 100
        if total <= 0 { return }

        db.execSQL("INSERT OR REPLACE INTO meta(k, v) VALUES('coins', ?)", [total.toString()])
        db.execSQL("INSERT OR REPLACE INTO meta(k, v) VALUES('coins_earned', ?)", [total.toString()])
        db.execSQL(
            "INSERT INTO wallet_log(at, kind, amount, note) VALUES(?, ?, ?, ?)",
            [
                System.currentTimeMillis(), "LEGACY", total,
                "그동안 공부한 보상 (알파벳 \(letters)자 · 레슨 \(lessons)판)",
            ]
        )
    }

    // ---------- meta ----------
    func meta(_ k: String, _ def: String = "") -> String {
        readableDatabase.rawQuery("SELECT v FROM meta WHERE k=?", [k]).use {
            $0.moveToFirst() ? $0.getString(0) : def
        }
    }

    func setMeta(_ k: String, _ v: String) {
        let cv = ContentValues()
        cv.put("k", k); cv.put("v", v)
        writableDatabase.insertWithOnConflict("meta", nil, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    func metaInt(_ k: String, _ def: Int = 0) -> Int { meta(k).toIntOrNull() ?? def }
    func metaLong(_ k: String, _ def: Int = 0) -> Int { meta(k).toLongOrNull() ?? def }

    // ---------- XP ----------
    func xp() -> Int { metaInt("xp") }

    func addXp(_ amount: Int) {
        setMeta("xp", (xp() + amount).toString())
        // 오늘 획득 XP (일일 목표용) — 날짜가 바뀌면 리셋
        let day = Db.today()
        let savedDay = metaLong("xp_today_day", -1)
        let base = savedDay == day ? metaInt("xp_today") : 0
        setMeta("xp_today_day", day.toString())
        setMeta("xp_today", (base + amount).toString())
    }

    /// 오늘 획득한 XP (날짜가 바뀌었으면 0)
    func xpToday() -> Int {
        metaLong("xp_today_day", -1) == Db.today() ? metaInt("xp_today") : 0
    }

    func dailyGoal() -> Int { metaInt("daily_goal", DailyGoal.DEFAULT) }
    func setDailyGoal(_ v: Int) { setMeta("daily_goal", v.toString()) }

    // ---------- 영역별 실력 ----------
    /// 문제 하나를 풀 때마다 호출. 첫 시도 결과만 반영한다.
    func recordSkill(_ skill: String, _ correct: Bool) {
        let db = writableDatabase
        db.execSQL("INSERT OR IGNORE INTO skills(skill, attempts, correct) VALUES(?, 0, 0)", [skill])
        db.execSQL(
            "UPDATE skills SET attempts = attempts + 1, correct = correct + ? WHERE skill = ?",
            [correct ? 1 : 0, skill]
        )
    }

    /// skill → (attempts, correct)
    func skillStats() -> [String: (first: Int, second: Int)] {
        var out: [String: (first: Int, second: Int)] = [:]
        readableDatabase.rawQuery("SELECT skill, attempts, correct FROM skills", nil).use {
            while $0.moveToNext() { out[$0.getString(0)] = ($0.getInt(1), $0.getInt(2)) }
        }
        return out
    }

    func skillStates(_ defs: [SkillDef] = Skills.ALL) -> [SkillState] {
        let stats = skillStats()
        return defs.map { d in
            let (a, c) = stats[d.id] ?? (0, 0)
            return SkillState(d, correct: c, attempts: a)
        }
    }

    // ---------- 하트 ----------
    /// 하트를 쓸지. **기본은 꺼짐** — 설정에서 켜면 원래 규칙(5개, 30분당 1개 회복)이 돌아온다.
    func heartsEnabled() -> Bool { meta("hearts_on") == "1" }

    func setHeartsEnabled(_ on: Bool) { setMeta("hearts_on", on ? "1" : "0") }

    func hearts() -> Int {
        let max = maxHearts()
        let saved = metaInt("hearts", max)
        let savedAt = metaLong("hearts_at", System.currentTimeMillis())
        let savedDay = metaLong("hearts_day", Db.today())
        let now = System.currentTimeMillis()
        let h = Economy.heartsNow(saved, savedAt, savedDay, now, Db.today(), max: max)
        if h != saved { setHearts(h) }
        return h
    }

    func setHearts(_ h: Int) {
        setMeta("hearts", h.coerceIn(0, maxHearts()).toString())
        setMeta("hearts_at", System.currentTimeMillis().toString())
        setMeta("hearts_day", Db.today().toString())
    }

    // ---------- 진행도 ----------
    func completeLesson(_ lessonId: String, _ track: String, _ stars: Int, _ acc: Float) {
        let prev = lessonStars(lessonId)
        let cv = ContentValues()
        cv.put("lesson_id", lessonId); cv.put("track", track)
        cv.put("stars", Swift.max(stars, prev)); cv.put("best_acc", acc)
        cv.put("completed_at", System.currentTimeMillis())
        writableDatabase.insertWithOnConflict("progress", nil, cv, SQLiteDatabase.CONFLICT_REPLACE)
        markToday()
    }

    func lessonStars(_ lessonId: String) -> Int {
        readableDatabase.rawQuery("SELECT stars FROM progress WHERE lesson_id=?", [lessonId]).use {
            $0.moveToFirst() ? $0.getInt(0) : 0
        }
    }

    func completedLessonIds() -> Set<String> {
        var s = Set<String>()
        readableDatabase.rawQuery("SELECT lesson_id FROM progress", nil).use {
            while $0.moveToNext() { s.insert($0.getString(0)) }
        }
        return s
    }

    func lessonsDoneCount() -> Int {
        readableDatabase.rawQuery("SELECT COUNT(*) FROM progress", nil).use {
            $0.moveToFirst(); return $0.getInt(0)
        }
    }

    // ---------- 오답 ----------
    func recordWrong(_ q: Question, _ lessonId: String, _ track: String) {
        let db = writableDatabase
        let exists = db.rawQuery("SELECT wrong FROM wrongs WHERE qid=?", [q.id]).use { $0.moveToFirst() }
        if exists {
            db.execSQL(
                "UPDATE wrongs SET wrong=wrong+1, ok_streak=0, cleared=0, last_at=? WHERE qid=?",
                [System.currentTimeMillis(), q.id]
            )
        } else {
            let cv = ContentValues()
            cv.put("qid", q.id); cv.put("lesson_id", lessonId); cv.put("track", track)
            cv.put("wrong", 1); cv.put("ok_streak", 0); cv.put("cleared", 0)
            cv.put("last_at", System.currentTimeMillis())
            db.insert("wrongs", nil, cv)
        }
    }

    /// 복습에서 정답 → ok_streak+1, 2연속이면 클리어. 오답 → 리셋. 이번에 클리어됐으면 true
    @discardableResult
    func reviewOutcome(_ qid: String, _ correct: Bool) -> Bool {
        let db = writableDatabase
        if !correct {
            db.execSQL("UPDATE wrongs SET ok_streak=0, wrong=wrong+1, last_at=? WHERE qid=?",
                       [System.currentTimeMillis(), qid])
            return false
        }
        db.execSQL("UPDATE wrongs SET ok_streak=ok_streak+1, last_at=? WHERE qid=?",
                   [System.currentTimeMillis(), qid])
        let streakOk = db.rawQuery("SELECT ok_streak FROM wrongs WHERE qid=?", [qid]).use {
            $0.moveToFirst() && $0.getInt(0) >= 2
        }
        if streakOk {
            db.execSQL("UPDATE wrongs SET cleared=1 WHERE qid=?", [qid])
            setMeta("review_cleared", (metaInt("review_cleared") + 1).toString())
            return true
        }
        return false
    }

    /// 복습 대상 (미클리어) — (qid, lesson_id, track) 많이 틀린·오래된 순
    func wrongList(_ limit: Int) -> [(first: String, second: String, third: String)] {
        var out: [(first: String, second: String, third: String)] = []
        readableDatabase.rawQuery(
            "SELECT qid, lesson_id, track FROM wrongs WHERE cleared=0 ORDER BY wrong DESC, last_at ASC LIMIT ?",
            [limit.toString()]
        ).use {
            while $0.moveToNext() { out.append(($0.getString(0), $0.getString(1), $0.getString(2))) }
        }
        return out
    }

    func wrongCount() -> Int {
        readableDatabase.rawQuery("SELECT COUNT(*) FROM wrongs WHERE cleared=0", nil).use {
            $0.moveToFirst(); return $0.getInt(0)
        }
    }

    // ---------- 지갑 (용돈) ----------
    func coins() -> Int { metaInt("coins") }
    func coinsEarned() -> Int { metaInt("coins_earned") }
    func coinsSpent() -> Int { metaInt("coins_spent") }
    func coinsPaidOut() -> Int { metaInt("coins_paid") }

    /// 코인 적립. amount>0 만 유효. 실제 적립액을 돌려준다
    @discardableResult
    func earnCoins(_ amount: Int, _ kind: String, _ note: String) -> Int {
        if amount <= 0 { return 0 }
        setMeta("coins", (coins() + amount).toString())
        setMeta("coins_earned", (coinsEarned() + amount).toString())
        logWallet(kind, amount, note)
        return amount
    }

    /// 코인 사용. 잔액이 모자라면 false
    @discardableResult
    func spendCoins(_ amount: Int, _ kind: String, _ note: String) -> Bool {
        if amount <= 0 || coins() < amount { return false }
        setMeta("coins", (coins() - amount).toString())
        if kind == "PAYOUT" { setMeta("coins_paid", (coinsPaidOut() + amount).toString()) }
        else { setMeta("coins_spent", (coinsSpent() + amount).toString()) }
        logWallet(kind, -amount, note)
        return true
    }

    private func logWallet(_ kind: String, _ amount: Int, _ note: String) {
        let cv = ContentValues()
        cv.put("at", System.currentTimeMillis()); cv.put("kind", kind)
        cv.put("amount", amount); cv.put("note", note)
        writableDatabase.insert("wallet_log", nil, cv)
    }

    func walletLog(_ limit: Int = 30) -> [WalletLog] {
        var out: [WalletLog] = []
        readableDatabase.rawQuery(
            "SELECT at, kind, amount, note FROM wallet_log ORDER BY id DESC LIMIT ?",
            [limit.toString()]
        ).use {
            while $0.moveToNext() {
                out.append(WalletLog($0.getLong(0), $0.getString(1), $0.getInt(2), $0.getString(3)))
            }
        }
        return out
    }

    /// 하루 한도가 있는 보너스: 오늘 몇 번 받았는지
    func bonusCountToday(_ kind: String) -> Int {
        let key = "bonus_\(kind)"
        return metaLong("\(key)_day", -1) == Db.today() ? metaInt(key) : 0
    }

    func addBonusCountToday(_ kind: String) {
        let key = "bonus_\(kind)"
        let n = bonusCountToday(kind)
        setMeta("\(key)_day", Db.today().toString())
        setMeta(key, (n + 1).toString())
    }

    // ---------- 인벤토리 ----------
    func itemCount(_ item: String) -> Int {
        readableDatabase.rawQuery("SELECT count FROM inventory WHERE item=?", [item]).use {
            $0.moveToFirst() ? $0.getInt(0) : 0
        }
    }

    func addItem(_ item: String, _ n: Int) {
        let db = writableDatabase
        db.execSQL("INSERT OR IGNORE INTO inventory(item, count) VALUES(?, 0)", [item])
        db.execSQL("UPDATE inventory SET count = count + ? WHERE item = ?", [n, item])
    }

    /// 소모품 1개 사용. 없으면 false
    @discardableResult
    func useItem(_ item: String) -> Bool {
        if itemCount(item) <= 0 { return false }
        writableDatabase.execSQL("UPDATE inventory SET count = count - 1 WHERE item = ?", [item])
        return true
    }

    func ownsItem(_ item: String) -> Bool { itemCount(item) > 0 }

    // ---------- 하트 최대치 / 꾸미기 ----------
    func maxHearts() -> Int {
        metaInt("max_hearts", Economy.MAX_HEARTS).coerceIn(Economy.MAX_HEARTS, Shop.MAX_HEARTS_CAP)
    }

    func setMaxHearts(_ v: Int) { setMeta("max_hearts", v.toString()) }

    func equippedSticker() -> String { meta("sticker") }
    func setEquippedSticker(_ emoji: String) { setMeta("sticker", emoji) }

    func themeColor() -> String { meta("theme_color").ifEmpty { Shop.DEFAULT_THEME_COLOR } }

    func setThemeColor(_ c: String) { setMeta("theme_color", c) }

    // ---------- 부모 잠금 ----------
    func parentPin() -> String { meta("parent_pin") }
    func setParentPin(_ pin: String) { setMeta("parent_pin", pin) }
    func hasParentPin() -> Bool { parentPin().isNotEmpty() }

    // ---------- 알파벳 쓰기 ----------
    /// 이 글자를 몇 번 썼는지
    func letterWrites(_ key: String) -> Int {
        readableDatabase.rawQuery("SELECT writes FROM letters WHERE key=?", [key]).use {
            $0.moveToFirst() ? $0.getInt(0) : 0
        }
    }

    /// 한 번 더 썼다. 누적 쓴 횟수를 돌려준다
    @discardableResult
    func addLetterWrite(_ key: String) -> Int {
        let db = writableDatabase
        db.execSQL(
            "INSERT OR IGNORE INTO letters(key, stars, writes, at) VALUES(?, 0, 0, ?)",
            [key, System.currentTimeMillis()]
        )
        db.execSQL(
            "UPDATE letters SET writes = writes + 1, at = ? WHERE key = ?",
            [System.currentTimeMillis(), key]
        )
        let n = letterWrites(key)
        // 많이 쓸수록 별이 늘어난다 (1회 ⭐ / 3회 ⭐⭐ / 5회 ⭐⭐⭐)
        setLetterStars(key, n >= 5 ? 3 : (n >= 3 ? 2 : 1))
        return n
    }

    func letterStars(_ key: String) -> Int {
        readableDatabase.rawQuery("SELECT stars FROM letters WHERE key=?", [key]).use {
            $0.moveToFirst() ? $0.getInt(0) : 0
        }
    }

    func setLetterStars(_ key: String, _ stars: Int) {
        let cv = ContentValues()
        cv.put("key", key); cv.put("stars", stars); cv.put("at", System.currentTimeMillis())
        writableDatabase.insertWithOnConflict("letters", nil, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    /// 다 쓴 글자 수 (대문자+소문자)
    func lettersDoneCount() -> Int {
        readableDatabase.rawQuery("SELECT COUNT(*) FROM letters WHERE stars > 0", nil).use {
            $0.moveToFirst(); return $0.getInt(0)
        }
    }

    // ---------- 스트릭 ----------
    func markToday() {
        writableDatabase.execSQL("INSERT OR IGNORE INTO days(day) VALUES(?)", [Db.today()])
    }

    func studyDays() -> Set<Int> {
        var s = Set<Int>()
        readableDatabase.rawQuery("SELECT day FROM days", nil).use {
            while $0.moveToNext() { s.insert($0.getLong(0)) }
        }
        return s
    }

    // ---------- 배지 ----------
    func earnedBadges() -> Set<String> {
        var s = Set<String>()
        readableDatabase.rawQuery("SELECT id FROM badges", nil).use {
            while $0.moveToNext() { s.insert($0.getString(0)) }
        }
        return s
    }

    func earnBadge(_ id: String) {
        let cv = ContentValues()
        cv.put("id", id); cv.put("at", System.currentTimeMillis())
        writableDatabase.insertWithOnConflict("badges", nil, cv, SQLiteDatabase.CONFLICT_IGNORE)
    }

    // ---------- 유닛 완료 수 (배지용) ----------
    func unitsCompleted(_ unitLessons: [String: [String: [String]]]) -> [String: Int] {
        let done = completedLessonIds()
        var out: [String: Int] = [:]
        for (track, units) in unitLessons {
            out[track] = units.values.filter { lessons in lessons.isNotEmpty() && lessons.allSatisfy { done.contains($0) } }.count
        }
        return out
    }

    // ---------- 초기화 ----------
    func resetAll() {
        let db = writableDatabase
        db.execSQL("DELETE FROM progress"); db.execSQL("DELETE FROM wrongs")
        db.execSQL("DELETE FROM days"); db.execSQL("DELETE FROM badges"); db.execSQL("DELETE FROM meta")
        db.execSQL("DELETE FROM skills"); db.execSQL("DELETE FROM letters")
        db.execSQL("DELETE FROM wallet_log"); db.execSQL("DELETE FROM inventory")
    }
}
