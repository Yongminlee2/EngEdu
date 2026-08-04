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
        val abroad = !com.piyak.english.i18n.Tpl.isKorean
        val unitsArr = o.getJSONArray("units")
        val units = (0 until unitsArr.length()).map { ui ->
            val u = unitsArr.getJSONObject(ui)
            val lessonsArr = u.getJSONArray("lessons")
            val lessons = (0 until lessonsArr.length()).map { li ->
                val l = lessonsArr.getJSONObject(li)
                val qArr = l.getJSONArray("questions")
                val all = (0 until qArr.length()).map { qi -> Question.fromJson(qArr.getJSONObject(qi)) }
                // 비한국어 폰: 한국어 없이는 성립하지 않는 문제(짝맞추기·한국어 독해 등)를 뺀다.
                // 한국어 폰은 그대로 — 지금까지의 경험이 하나도 안 바뀐다.
                val qs = if (abroad) all.filter { usableAbroad(it) } else all
                LessonData(l.getString("id"), title(l), qs)
            }.filter { it.questions.size >= if (abroad) 1 else 0 }
            UnitData(u.getString("id"), title(u), u.optString("emoji", "🐥"),
                u.optInt("level", ui + 1), lessons)
        }.filter { !abroad || it.lessons.isNotEmpty() }
        return TrackData(
            o.getString("id"), title(o), o.optString("emoji", "🐥"),
            o.optString("color", "#FFD54F"), title(o, "stk", "sta", "subtitle"), units
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
            }.filter { com.piyak.english.i18n.Tpl.isKorean || usableAbroad(it.second) }
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

    /** 팩의 tk/ta 를 폰 언어 제목으로 조립한다 (한국어 폰·미태깅 제목은 원문 그대로) */
    private fun title(o: JSONObject, key: String = "tk", args: String = "ta", field: String = "title"): String {
        val ko = o.optString(field)
        val tk = o.optString(key)
        if (tk.isEmpty()) return ko
        val ta = o.optJSONArray(args)
        val list = if (ta == null) emptyList() else (0 until ta.length()).map { ta.getString(it) }
        return com.piyak.english.i18n.Tpl.sentence(tk, list, ko)
    }

    /**
     * 비한국어 폰에서 한국어 없이 풀 수 있는 문제인가.
     *
     * - 짝맞추기: 짝의 한쪽이 한국어 뜻이라 성립 불가 → 뺀다
     * - 독해·대화듣기: 질문·보기가 한국어 → 뺀다
     * - 4지선다: 문제문이 한국어라도 그림(bigArt)이 있으면 그림 문제로 바뀌므로 통과,
     *   보기가 한국어라도 그림 보기(choiceArt)가 있으면 통과
     */
    private fun usableAbroad(q: Question): Boolean = when (q) {
        is Question.Match -> q.pairs.none { hasKo(it.first) || hasKo(it.second) }
        is Question.ListenDialog -> !hasKo(q.prompt) && q.choices.none { hasKo(it) }
        is Question.Mcq ->
            (!hasKo(q.prompt) || q.bigArt != null) &&
                (q.choices.none { hasKo(it) } || q.choiceArt.isNotEmpty())
        is Question.ListenMcq -> !hasKo(q.prompt) && q.choices.none { hasKo(it) }
        else -> true
    }

    private fun hasKo(s: String): Boolean {
        for (c in s) if (c in '가'..'힣') return true
        return false
    }

}
