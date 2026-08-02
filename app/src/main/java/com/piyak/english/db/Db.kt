package com.piyak.english.db

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.piyak.english.engine.Economy
import com.piyak.english.model.Question
import java.time.LocalDate

// 스키마를 바꾸는 마이그레이션(onUpgrade 의 oldV < N)을 추가하면 **여기 버전도 N 으로 올려야 한다.**
// v2.0 에서 writes 열 마이그레이션을 써 놓고 버전을 5에 둔 채 내보내는 바람에,
// 업그레이드된 폰에서만 열이 없어 알파벳 화면이 죽었다 (새 설치는 onCreate 가 커버해서 멀쩡했다).
class Db private constructor(ctx: Context) : SQLiteOpenHelper(ctx, "piyak.db", null, 6) {

    companion object {
        @Volatile private var inst: Db? = null
        fun get(ctx: Context): Db =
            inst ?: synchronized(this) { inst ?: Db(ctx.applicationContext).also { inst = it } }

        fun today(): Long = LocalDate.now().toEpochDay()
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE progress(lesson_id TEXT PRIMARY KEY, track TEXT, stars INTEGER, best_acc REAL, completed_at INTEGER)")
        db.execSQL("CREATE TABLE wrongs(qid TEXT PRIMARY KEY, lesson_id TEXT, track TEXT, wrong INTEGER DEFAULT 1, ok_streak INTEGER DEFAULT 0, cleared INTEGER DEFAULT 0, last_at INTEGER)")
        db.execSQL("CREATE TABLE days(day INTEGER PRIMARY KEY)")
        db.execSQL("CREATE TABLE badges(id TEXT PRIMARY KEY, at INTEGER)")
        db.execSQL("CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)")
        db.execSQL("CREATE TABLE skills(skill TEXT PRIMARY KEY, attempts INTEGER DEFAULT 0, correct INTEGER DEFAULT 0)")
        db.execSQL("CREATE TABLE letters(key TEXT PRIMARY KEY, stars INTEGER DEFAULT 0, writes INTEGER DEFAULT 0, at INTEGER)")
        createWalletTables(db)
    }

    private fun createWalletTables(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS wallet_log(" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER, kind TEXT, amount INTEGER, note TEXT)"
        )
        db.execSQL("CREATE TABLE IF NOT EXISTS inventory(item TEXT PRIMARY KEY, count INTEGER DEFAULT 0)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldV: Int, newV: Int) {
        if (oldV < 2) {
            db.execSQL("CREATE TABLE IF NOT EXISTS skills(skill TEXT PRIMARY KEY, attempts INTEGER DEFAULT 0, correct INTEGER DEFAULT 0)")
        }
        if (oldV < 3) {
            db.execSQL("CREATE TABLE IF NOT EXISTS letters(key TEXT PRIMARY KEY, stars INTEGER DEFAULT 0, at INTEGER)")
        }
        if (oldV < 4) createWalletTables(db)
        if (oldV < 6) {
            // 알파벳을 여러 번 쓸 수 있게 되면서 쓴 횟수를 센다
            runCatching {
                db.execSQL("ALTER TABLE letters ADD COLUMN writes INTEGER DEFAULT 0")
            }
            // 이미 완성한 글자는 1회 쓴 것으로 인정
            db.execSQL("UPDATE letters SET writes = 1 WHERE stars > 0 AND writes = 0")
        }
        // 용돈 기능이 생기기 전에 이미 해 둔 공부에도 소급해서 보상한다
        if (oldV < 5) grantLegacyRewards(db)
    }

    private fun grantLegacyRewards(db: SQLiteDatabase) {
        var total = 0
        var letters = 0
        var lessons = 0
        db.rawQuery("SELECT COUNT(*) FROM letters WHERE stars > 0", null).use {
            if (it.moveToFirst()) letters = it.getInt(0)
        }
        db.rawQuery("SELECT COUNT(*) FROM progress", null).use {
            if (it.moveToFirst()) lessons = it.getInt(0)
        }
        total += letters * com.piyak.english.engine.Wallet.PER_LETTER
        // 지난 레슨은 문제별 기록이 없으니 한 판당 100원으로 셈한다
        total += lessons * 100
        if (total <= 0) return

        db.execSQL("INSERT OR REPLACE INTO meta(k, v) VALUES('coins', ?)", arrayOf(total.toString()))
        db.execSQL("INSERT OR REPLACE INTO meta(k, v) VALUES('coins_earned', ?)", arrayOf(total.toString()))
        db.execSQL(
            "INSERT INTO wallet_log(at, kind, amount, note) VALUES(?, ?, ?, ?)",
            arrayOf(
                System.currentTimeMillis(), "LEGACY", total,
                "그동안 공부한 보상 (알파벳 ${letters}자 · 레슨 ${lessons}판)"
            )
        )
    }

    // ---------- meta ----------
    fun meta(k: String, def: String = ""): String {
        readableDatabase.rawQuery("SELECT v FROM meta WHERE k=?", arrayOf(k)).use {
            return if (it.moveToFirst()) it.getString(0) else def
        }
    }

    fun setMeta(k: String, v: String) {
        val cv = ContentValues().apply { put("k", k); put("v", v) }
        writableDatabase.insertWithOnConflict("meta", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun metaInt(k: String, def: Int = 0): Int = meta(k).toIntOrNull() ?: def
    fun metaLong(k: String, def: Long = 0): Long = meta(k).toLongOrNull() ?: def

    // ---------- XP ----------
    fun xp(): Int = metaInt("xp")

    fun addXp(amount: Int) {
        setMeta("xp", (xp() + amount).toString())
        // 오늘 획득 XP (일일 목표용) — 날짜가 바뀌면 리셋
        val day = today()
        val savedDay = metaLong("xp_today_day", -1)
        val base = if (savedDay == day) metaInt("xp_today") else 0
        setMeta("xp_today_day", day.toString())
        setMeta("xp_today", (base + amount).toString())
    }

    /** 오늘 획득한 XP (날짜가 바뀌었으면 0) */
    fun xpToday(): Int =
        if (metaLong("xp_today_day", -1) == today()) metaInt("xp_today") else 0

    fun dailyGoal(): Int = metaInt("daily_goal", com.piyak.english.engine.DailyGoal.DEFAULT)
    fun setDailyGoal(v: Int) = setMeta("daily_goal", v.toString())

    // ---------- 영역별 실력 ----------
    /** 문제 하나를 풀 때마다 호출. 첫 시도 결과만 반영한다. */
    fun recordSkill(skill: String, correct: Boolean) {
        val db = writableDatabase
        db.execSQL("INSERT OR IGNORE INTO skills(skill, attempts, correct) VALUES(?, 0, 0)", arrayOf(skill))
        db.execSQL(
            "UPDATE skills SET attempts = attempts + 1, correct = correct + ? WHERE skill = ?",
            arrayOf(if (correct) 1 else 0, skill)
        )
    }

    /** skill → (attempts, correct) */
    fun skillStats(): Map<String, Pair<Int, Int>> {
        val out = HashMap<String, Pair<Int, Int>>()
        readableDatabase.rawQuery("SELECT skill, attempts, correct FROM skills", null).use {
            while (it.moveToNext()) out[it.getString(0)] = it.getInt(1) to it.getInt(2)
        }
        return out
    }

    fun skillStates(
        defs: List<com.piyak.english.engine.SkillDef> = com.piyak.english.engine.Skills.ALL,
    ): List<com.piyak.english.engine.SkillState> {
        val stats = skillStats()
        return defs.map { d ->
            val (a, c) = stats[d.id] ?: (0 to 0)
            com.piyak.english.engine.SkillState(d, correct = c, attempts = a)
        }
    }

    // ---------- 하트 ----------
    /**
     * 하트를 쓸지. 끄면 하트가 줄지 않고 화면에도 안 나온다.
     *
     * **기본은 꺼짐** — 콘텐츠를 훑어보며 테스트할 때 하트가 떨어져 막히는 게 더 큰 불편이라
     * 그렇게 뒀다. 아이에게 줄 때 설정에서 켜면 원래의 하트 규칙(5개, 30분당 1개 회복)이 돌아온다.
     */
    fun heartsEnabled(): Boolean = meta("hearts_on") == "1"

    fun setHeartsEnabled(on: Boolean) = setMeta("hearts_on", if (on) "1" else "0")

    fun hearts(): Int {
        val max = maxHearts()
        val saved = metaInt("hearts", max)
        val savedAt = metaLong("hearts_at", System.currentTimeMillis())
        val savedDay = metaLong("hearts_day", today())
        val now = System.currentTimeMillis()
        val h = Economy.heartsNow(saved, savedAt, savedDay, now, today(), max)
        if (h != saved) setHearts(h)
        return h
    }

    fun setHearts(h: Int) {
        setMeta("hearts", h.coerceIn(0, maxHearts()).toString())
        setMeta("hearts_at", System.currentTimeMillis().toString())
        setMeta("hearts_day", today().toString())
    }

    // ---------- 진행도 ----------
    fun completeLesson(lessonId: String, track: String, stars: Int, acc: Float) {
        val prev = lessonStars(lessonId)
        val cv = ContentValues().apply {
            put("lesson_id", lessonId); put("track", track)
            put("stars", maxOf(stars, prev)); put("best_acc", acc)
            put("completed_at", System.currentTimeMillis())
        }
        writableDatabase.insertWithOnConflict("progress", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
        markToday()
    }

    fun lessonStars(lessonId: String): Int {
        readableDatabase.rawQuery("SELECT stars FROM progress WHERE lesson_id=?", arrayOf(lessonId)).use {
            return if (it.moveToFirst()) it.getInt(0) else 0
        }
    }

    fun completedLessonIds(): Set<String> {
        val s = HashSet<String>()
        readableDatabase.rawQuery("SELECT lesson_id FROM progress", null).use {
            while (it.moveToNext()) s.add(it.getString(0))
        }
        return s
    }

    fun lessonsDoneCount(): Int {
        readableDatabase.rawQuery("SELECT COUNT(*) FROM progress", null).use {
            it.moveToFirst(); return it.getInt(0)
        }
    }

    // ---------- 오답 ----------
    fun recordWrong(q: Question, lessonId: String, track: String) {
        val db = writableDatabase
        db.rawQuery("SELECT wrong FROM wrongs WHERE qid=?", arrayOf(q.id)).use {
            if (it.moveToFirst()) {
                db.execSQL(
                    "UPDATE wrongs SET wrong=wrong+1, ok_streak=0, cleared=0, last_at=? WHERE qid=?",
                    arrayOf(System.currentTimeMillis(), q.id)
                )
            } else {
                val cv = ContentValues().apply {
                    put("qid", q.id); put("lesson_id", lessonId); put("track", track)
                    put("wrong", 1); put("ok_streak", 0); put("cleared", 0)
                    put("last_at", System.currentTimeMillis())
                }
                db.insert("wrongs", null, cv)
            }
        }
    }

    /** 복습에서 정답 → ok_streak+1, 2연속이면 클리어. 오답 → 리셋. @return 이번에 클리어됐는지 */
    fun reviewOutcome(qid: String, correct: Boolean): Boolean {
        val db = writableDatabase
        if (!correct) {
            db.execSQL("UPDATE wrongs SET ok_streak=0, wrong=wrong+1, last_at=? WHERE qid=?",
                arrayOf(System.currentTimeMillis(), qid))
            return false
        }
        db.execSQL("UPDATE wrongs SET ok_streak=ok_streak+1, last_at=? WHERE qid=?",
            arrayOf(System.currentTimeMillis(), qid))
        db.rawQuery("SELECT ok_streak FROM wrongs WHERE qid=?", arrayOf(qid)).use {
            if (it.moveToFirst() && it.getInt(0) >= 2) {
                db.execSQL("UPDATE wrongs SET cleared=1 WHERE qid=?", arrayOf(qid))
                setMeta("review_cleared", (metaInt("review_cleared") + 1).toString())
                return true
            }
        }
        return false
    }

    /** 복습 대상 (미클리어) — (qid, lesson_id, track) 오래된·많이틀린 순 */
    fun wrongList(limit: Int): List<Triple<String, String, String>> {
        val out = ArrayList<Triple<String, String, String>>()
        readableDatabase.rawQuery(
            "SELECT qid, lesson_id, track FROM wrongs WHERE cleared=0 ORDER BY wrong DESC, last_at ASC LIMIT ?",
            arrayOf(limit.toString())
        ).use {
            while (it.moveToNext()) out.add(Triple(it.getString(0), it.getString(1), it.getString(2)))
        }
        return out
    }

    fun wrongCount(): Int {
        readableDatabase.rawQuery("SELECT COUNT(*) FROM wrongs WHERE cleared=0", null).use {
            it.moveToFirst(); return it.getInt(0)
        }
    }

    // ---------- 지갑 (용돈) ----------
    fun coins(): Int = metaInt("coins")
    fun coinsEarned(): Int = metaInt("coins_earned")
    fun coinsSpent(): Int = metaInt("coins_spent")
    fun coinsPaidOut(): Int = metaInt("coins_paid")

    /** 코인 적립. amount>0 만 유효. @return 실제 적립액 */
    fun earnCoins(amount: Int, kind: String, note: String): Int {
        if (amount <= 0) return 0
        setMeta("coins", (coins() + amount).toString())
        setMeta("coins_earned", (coinsEarned() + amount).toString())
        logWallet(kind, amount, note)
        return amount
    }

    /** 코인 사용. 잔액이 모자라면 false */
    fun spendCoins(amount: Int, kind: String, note: String): Boolean {
        if (amount <= 0 || coins() < amount) return false
        setMeta("coins", (coins() - amount).toString())
        if (kind == "PAYOUT") setMeta("coins_paid", (coinsPaidOut() + amount).toString())
        else setMeta("coins_spent", (coinsSpent() + amount).toString())
        logWallet(kind, -amount, note)
        return true
    }

    private fun logWallet(kind: String, amount: Int, note: String) {
        val cv = ContentValues().apply {
            put("at", System.currentTimeMillis()); put("kind", kind)
            put("amount", amount); put("note", note)
        }
        writableDatabase.insert("wallet_log", null, cv)
    }

    fun walletLog(limit: Int = 30): List<com.piyak.english.engine.WalletLog> {
        val out = ArrayList<com.piyak.english.engine.WalletLog>()
        readableDatabase.rawQuery(
            "SELECT at, kind, amount, note FROM wallet_log ORDER BY id DESC LIMIT ?",
            arrayOf(limit.toString())
        ).use {
            while (it.moveToNext()) {
                out.add(
                    com.piyak.english.engine.WalletLog(
                        it.getLong(0), it.getString(1), it.getInt(2), it.getString(3) ?: ""
                    )
                )
            }
        }
        return out
    }

    /** 하루 한도가 있는 보너스: 오늘 몇 번 받았는지 */
    fun bonusCountToday(kind: String): Int {
        val key = "bonus_${kind}"
        return if (metaLong("${key}_day", -1) == today()) metaInt(key) else 0
    }

    fun addBonusCountToday(kind: String) {
        val key = "bonus_${kind}"
        val n = bonusCountToday(kind)
        setMeta("${key}_day", today().toString())
        setMeta(key, (n + 1).toString())
    }

    // ---------- 인벤토리 ----------
    fun itemCount(item: String): Int {
        readableDatabase.rawQuery("SELECT count FROM inventory WHERE item=?", arrayOf(item)).use {
            return if (it.moveToFirst()) it.getInt(0) else 0
        }
    }

    fun addItem(item: String, n: Int) {
        val db = writableDatabase
        db.execSQL("INSERT OR IGNORE INTO inventory(item, count) VALUES(?, 0)", arrayOf(item))
        db.execSQL("UPDATE inventory SET count = count + ? WHERE item = ?", arrayOf(n, item))
    }

    /** 소모품 1개 사용. 없으면 false */
    fun useItem(item: String): Boolean {
        if (itemCount(item) <= 0) return false
        writableDatabase.execSQL("UPDATE inventory SET count = count - 1 WHERE item = ?", arrayOf(item))
        return true
    }

    fun ownsItem(item: String): Boolean = itemCount(item) > 0

    // ---------- 하트 최대치 / 꾸미기 ----------
    fun maxHearts(): Int =
        metaInt("max_hearts", com.piyak.english.engine.Economy.MAX_HEARTS)
            .coerceIn(com.piyak.english.engine.Economy.MAX_HEARTS, com.piyak.english.engine.Shop.MAX_HEARTS_CAP)

    fun setMaxHearts(v: Int) = setMeta("max_hearts", v.toString())

    fun equippedSticker(): String = meta("sticker")
    fun setEquippedSticker(emoji: String) = setMeta("sticker", emoji)

    fun themeColor(): String =
        meta("theme_color").ifEmpty { com.piyak.english.engine.Shop.DEFAULT_THEME_COLOR }

    fun setThemeColor(c: String) = setMeta("theme_color", c)

    // ---------- 부모 잠금 ----------
    fun parentPin(): String = meta("parent_pin")
    fun setParentPin(pin: String) = setMeta("parent_pin", pin)
    fun hasParentPin(): Boolean = parentPin().isNotEmpty()

    // ---------- 알파벳 쓰기 ----------
    /** 이 글자를 몇 번 썼는지 */
    fun letterWrites(key: String): Int {
        readableDatabase.rawQuery("SELECT writes FROM letters WHERE key=?", arrayOf(key)).use {
            return if (it.moveToFirst()) it.getInt(0) else 0
        }
    }

    /** 한 번 더 썼다. @return 누적 쓴 횟수 */
    fun addLetterWrite(key: String): Int {
        val db = writableDatabase
        db.execSQL(
            "INSERT OR IGNORE INTO letters(key, stars, writes, at) VALUES(?, 0, 0, ?)",
            arrayOf(key, System.currentTimeMillis())
        )
        db.execSQL(
            "UPDATE letters SET writes = writes + 1, at = ? WHERE key = ?",
            arrayOf(System.currentTimeMillis(), key)
        )
        val n = letterWrites(key)
        // 많이 쓸수록 별이 늘어난다 (1회 ⭐ / 3회 ⭐⭐ / 5회 ⭐⭐⭐)
        setLetterStars(key, if (n >= 5) 3 else if (n >= 3) 2 else 1)
        return n
    }

    fun letterStars(key: String): Int {
        readableDatabase.rawQuery("SELECT stars FROM letters WHERE key=?", arrayOf(key)).use {
            return if (it.moveToFirst()) it.getInt(0) else 0
        }
    }

    fun setLetterStars(key: String, stars: Int) {
        val cv = ContentValues().apply {
            put("key", key); put("stars", stars); put("at", System.currentTimeMillis())
        }
        writableDatabase.insertWithOnConflict("letters", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    /** 다 쓴 글자 수 (대문자+소문자) */
    fun lettersDoneCount(): Int {
        readableDatabase.rawQuery("SELECT COUNT(*) FROM letters WHERE stars > 0", null).use {
            it.moveToFirst(); return it.getInt(0)
        }
    }

    // ---------- 스트릭 ----------
    fun markToday() {
        writableDatabase.execSQL("INSERT OR IGNORE INTO days(day) VALUES(?)", arrayOf(today()))
    }

    fun studyDays(): Set<Long> {
        val s = HashSet<Long>()
        readableDatabase.rawQuery("SELECT day FROM days", null).use {
            while (it.moveToNext()) s.add(it.getLong(0))
        }
        return s
    }

    // ---------- 배지 ----------
    fun earnedBadges(): Set<String> {
        val s = HashSet<String>()
        readableDatabase.rawQuery("SELECT id FROM badges", null).use {
            while (it.moveToNext()) s.add(it.getString(0))
        }
        return s
    }

    fun earnBadge(id: String) {
        val cv = ContentValues().apply { put("id", id); put("at", System.currentTimeMillis()) }
        writableDatabase.insertWithOnConflict("badges", null, cv, SQLiteDatabase.CONFLICT_IGNORE)
    }

    // ---------- 유닛 완료 수 (배지용) ----------
    fun unitsCompleted(unitLessons: Map<String, Map<String, List<String>>>): Map<String, Int> {
        val done = completedLessonIds()
        val out = HashMap<String, Int>()
        for ((track, units) in unitLessons) {
            out[track] = units.values.count { lessons -> lessons.isNotEmpty() && lessons.all { it in done } }
        }
        return out
    }

    // ---------- 초기화 ----------
    fun resetAll() {
        val db = writableDatabase
        db.execSQL("DELETE FROM progress"); db.execSQL("DELETE FROM wrongs")
        db.execSQL("DELETE FROM days"); db.execSQL("DELETE FROM badges"); db.execSQL("DELETE FROM meta")
        db.execSQL("DELETE FROM skills"); db.execSQL("DELETE FROM letters")
        db.execSQL("DELETE FROM wallet_log"); db.execSQL("DELETE FROM inventory")
    }
}
