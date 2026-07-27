package com.piyak.english.model

import android.content.Context
import org.json.JSONObject

data class LessonData(val id: String, val title: String, val questions: List<Question>)

data class UnitData(
    val id: String,
    val title: String,
    val emoji: String,
    val level: Int, // BASIC 은 1~10, 나머지 트랙은 유닛 순번
    val lessons: List<LessonData>,
)

data class TrackData(
    val id: String,
    val title: String,
    val emoji: String,
    val color: String,
    val subtitle: String,
    val units: List<UnitData>,
) {
    val lessonCount: Int get() = units.sumOf { it.lessons.size }
    fun findLesson(lessonId: String): Pair<UnitData, LessonData>? {
        for (u in units) for (l in u.lessons) if (l.id == lessonId) return u to l
        return null
    }
}

/** assets 의 packs 폴더 JSON 로더. 트랙별 lazy 캐시. */
object ContentRepo {
    val TRACK_IDS = listOf(
        "basic", "daily", "toeic", "toefl",
        "listening", "speaking", "writing", "grammar", "reading",
    )

    private val cache = HashMap<String, TrackData>()

    @Synchronized
    fun track(ctx: Context, trackId: String): TrackData? {
        cache[trackId]?.let { return it }
        return try {
            val json = ctx.assets.open("packs/$trackId.json").bufferedReader().use { it.readText() }
            val t = parseTrack(JSONObject(json))
            cache[trackId] = t
            t
        } catch (e: Exception) {
            null
        }
    }

    fun parseTrack(o: JSONObject): TrackData {
        val unitsArr = o.getJSONArray("units")
        val units = (0 until unitsArr.length()).map { ui ->
            val u = unitsArr.getJSONObject(ui)
            val lessonsArr = u.getJSONArray("lessons")
            val lessons = (0 until lessonsArr.length()).map { li ->
                val l = lessonsArr.getJSONObject(li)
                val qArr = l.getJSONArray("questions")
                val qs = (0 until qArr.length()).map { qi -> Question.fromJson(qArr.getJSONObject(qi)) }
                LessonData(l.getString("id"), l.getString("title"), qs)
            }
            UnitData(u.getString("id"), u.getString("title"), u.optString("emoji", "🐥"),
                u.optInt("level", ui + 1), lessons)
        }
        return TrackData(
            o.getString("id"), o.getString("title"), o.optString("emoji", "🐥"),
            o.optString("color", "#FFD54F"), o.optString("subtitle", ""), units
        )
    }

    /** 배치고사 문제: (난이도 1~10, 문제) 목록 */
    @Synchronized
    fun placement(ctx: Context): List<Pair<Int, Question>> {
        return try {
            val json = ctx.assets.open("packs/placement.json").bufferedReader().use { it.readText() }
            val arr = JSONObject(json).getJSONArray("questions")
            (0 until arr.length()).map {
                val q = arr.getJSONObject(it)
                q.getInt("level") to Question.fromJson(q)
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** 오답 복습용: qid 로 문제 찾기 (트랙 전체 스캔, 캐시 활용) */
    fun findQuestion(ctx: Context, trackId: String, lessonId: String, qid: String): Question? {
        val t = track(ctx, trackId) ?: return null
        val lesson = t.findLesson(lessonId)?.second ?: return null
        return lesson.questions.firstOrNull { it.id == qid }
    }
}
