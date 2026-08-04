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
    /** 이 앱이 싣는 트랙 — 삐약영어는 영어만 (Subject.MATH 는 모델로만 남아 있다) */
    val TRACK_IDS: List<String> = Subject.ENGLISH.tracks

    fun tracksOf(subject: Subject): List<String> = subject.tracks

    private val cache = HashMap<String, TrackData>()

    @Synchronized
    fun track(ctx: Context, trackId: String): TrackData? {
        cache[trackId]?.let { return it }
        com.piyak.english.i18n.Tpl.init(ctx)      // 문제를 만들기 전에 언어부터 확인
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

    /** 배치고사 문제: (난이도, 문제) 목록. 과목마다 팩이 다르다. */
    @Synchronized
    fun placement(ctx: Context, subject: Subject = Subject.ENGLISH): List<Pair<Int, Question>> {
        val file = if (subject == Subject.MATH) "packs/math_placement.json" else "packs/placement.json"
        return try {
            val json = ctx.assets.open(file).bufferedReader().use { it.readText() }
            val arr = JSONObject(json).getJSONArray("questions")
            (0 until arr.length()).map {
                val q = arr.getJSONObject(it)
                q.getInt("level") to Question.fromJson(q)
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** 트랙 요약(레슨 수·문제 수). 시작 화면에서 팩을 전부 파싱하지 않으려고 미리 구워 둔 색인. */
    data class TrackSummary(val lessons: Int, val questions: Int)

    private var summaryCache: Map<String, TrackSummary>? = null

    @Synchronized
    fun summaries(ctx: Context): Map<String, TrackSummary> {
        summaryCache?.let { return it }
        val out = HashMap<String, TrackSummary>()
        try {
            val json = ctx.assets.open("packs/index.json").bufferedReader().use { it.readText() }
            val o = JSONObject(json)
            for (key in o.keys()) {
                val e = o.getJSONObject(key)
                out[key] = TrackSummary(e.optInt("lessons"), e.optInt("questions"))
            }
        } catch (e: Exception) {
            // 색인이 없으면 0으로 두고 넘어간다 (진행률만 안 보일 뿐 학습에는 지장 없음)
        }
        summaryCache = out
        return out
    }

    /** 과목 전체 레슨 수 (색인 기반이라 팩을 열지 않는다) */
    fun lessonCountOf(ctx: Context, subject: Subject): Int =
        summaries(ctx).let { s -> subject.tracks.sumOf { s[it]?.lessons ?: 0 } }

    /** 오답 복습용: qid 로 문제 찾기 (트랙 전체 스캔, 캐시 활용) */
    fun findQuestion(ctx: Context, trackId: String, lessonId: String, qid: String): Question? {
        val t = track(ctx, trackId) ?: return null
        val lesson = t.findLesson(lessonId)?.second ?: return null
        return lesson.questions.firstOrNull { it.id == qid }
    }
}
