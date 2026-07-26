package com.piyak.english.db

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.piyak.english.engine.Economy
import com.piyak.english.model.Question
import java.time.LocalDate

class Db private constructor(ctx: Context) : SQLiteOpenHelper(ctx, "piyak.db", null, 1) {

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
    }

    override fun onUpgrade(db: SQLiteDatabase, oldV: Int, newV: Int) {}

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
    fun addXp(amount: Int) = setMeta("xp", (xp() + amount).toString())

    // ---------- 하트 ----------
    fun hearts(): Int {
        val saved = metaInt("hearts", Economy.MAX_HEARTS)
        val savedAt = metaLong("hearts_at", System.currentTimeMillis())
        val savedDay = metaLong("hearts_day", today())
        val now = System.currentTimeMillis()
        val h = Economy.heartsNow(saved, savedAt, savedDay, now, today())
        if (h != saved) setHearts(h)
        return h
    }

    fun setHearts(h: Int) {
        setMeta("hearts", h.coerceIn(0, Economy.MAX_HEARTS).toString())
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
    }
}
