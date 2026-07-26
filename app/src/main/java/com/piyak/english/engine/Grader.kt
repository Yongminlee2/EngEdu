package com.piyak.english.engine

import kotlin.math.max
import kotlin.math.min

/** 채점 결과: 정답 여부 + 오타 인정 여부 */
data class GradeResult(val correct: Boolean, val typo: Boolean = false)

object Grader {

    private val CONTRACTIONS = listOf(
        "i'm" to "i am", "you're" to "you are", "he's" to "he is", "she's" to "she is",
        "it's" to "it is", "we're" to "we are", "they're" to "they are",
        "i've" to "i have", "you've" to "you have", "we've" to "we have", "they've" to "they have",
        "i'll" to "i will", "you'll" to "you will", "he'll" to "he will", "she'll" to "she will",
        "we'll" to "we will", "they'll" to "they will", "it'll" to "it will",
        "i'd" to "i would", "you'd" to "you would", "he'd" to "he would", "she'd" to "she would",
        "we'd" to "we would", "they'd" to "they would",
        "isn't" to "is not", "aren't" to "are not", "wasn't" to "was not", "weren't" to "were not",
        "don't" to "do not", "doesn't" to "does not", "didn't" to "did not",
        "can't" to "cannot", "couldn't" to "could not", "won't" to "will not",
        "wouldn't" to "would not", "shouldn't" to "should not", "mustn't" to "must not",
        "haven't" to "have not", "hasn't" to "has not", "hadn't" to "had not",
        "let's" to "let us", "that's" to "that is", "there's" to "there is",
        "what's" to "what is", "where's" to "where is", "who's" to "who is", "how's" to "how is",
    )

    /** 소문자화 → 축약형 전개 → 구두점 제거 → 공백 축약 */
    fun normalize(s: String): String {
        var t = s.trim().lowercase()
            .replace('’', '\'').replace('‘', '\'')
            .replace('“', '"').replace('”', '"')
        for ((c, full) in CONTRACTIONS) {
            t = t.replace(Regex("\\b" + Regex.escape(c) + "\\b"), full)
        }
        t = t.replace(Regex("[^a-z0-9' ]"), " ")
            .replace(Regex("'(?=\\s|$)|(?<=\\s|^)'"), " ") // 낱개 아포스트로피 제거
            .replace(Regex("\\s+"), " ").trim()
        return t
    }

    /** 받아쓰기·타이핑 번역 채점. 오타(편집거리) 허용. */
    fun grade(input: String, answer: String, alts: List<String> = emptyList()): GradeResult {
        val inN = normalize(input)
        if (inN.isEmpty()) return GradeResult(false)
        val answers = (listOf(answer) + alts).map { normalize(it) }
        if (answers.any { it == inN }) return GradeResult(true)
        // 오타 인정: 답 길이 >4 → 거리 1, >10 → 거리 2
        for (a in answers) {
            val tol = when {
                a.length > 10 -> 2
                a.length > 4 -> 1
                else -> 0
            }
            if (tol > 0 && levenshtein(inN, a, tol) <= tol) return GradeResult(true, typo = true)
        }
        return GradeResult(false)
    }

    /** 단어 타일 배열 채점 */
    fun gradeOrder(selected: List<String>, answerTokens: List<String>): Boolean =
        selected == answerTokens

    /** 말하기 채점: 토큰 유사도(1-WER). 4단어 이상 0.75, 3단어 1오차, 1~2단어 정확히. */
    fun gradeSpeak(recognized: String, target: String): Boolean {
        val r = normalize(recognized).split(" ").filter { it.isNotEmpty() }
        val t = normalize(target).split(" ").filter { it.isNotEmpty() }
        if (t.isEmpty()) return false
        if (r.isEmpty()) return false
        val dist = tokenLevenshtein(r, t)
        return when {
            t.size >= 4 -> 1.0 - dist.toDouble() / t.size >= 0.75
            t.size == 3 -> dist <= 1
            else -> dist == 0
        }
    }

    /** 말하기 유사도 점수 0~100 (표시용) */
    fun speakScore(recognized: String, target: String): Int {
        val r = normalize(recognized).split(" ").filter { it.isNotEmpty() }
        val t = normalize(target).split(" ").filter { it.isNotEmpty() }
        if (t.isEmpty() || r.isEmpty()) return 0
        val dist = tokenLevenshtein(r, t)
        return max(0.0, (1.0 - dist.toDouble() / max(t.size, r.size)) * 100).toInt()
    }

    /** 문자 단위 편집거리 (조기 종료 임계값 지원) */
    fun levenshtein(a: String, b: String, cap: Int = Int.MAX_VALUE): Int {
        if (a == b) return 0
        if (kotlin.math.abs(a.length - b.length) > cap) return cap + 1
        var prev = IntArray(b.length + 1) { it }
        var cur = IntArray(b.length + 1)
        for (i in 1..a.length) {
            cur[0] = i
            var rowMin = cur[0]
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost)
                rowMin = min(rowMin, cur[j])
            }
            if (rowMin > cap) return cap + 1
            val tmp = prev; prev = cur; cur = tmp
        }
        return prev[b.length]
    }

    private fun tokenLevenshtein(a: List<String>, b: List<String>): Int {
        var prev = IntArray(b.size + 1) { it }
        var cur = IntArray(b.size + 1)
        for (i in 1..a.size) {
            cur[0] = i
            for (j in 1..b.size) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost)
            }
            val tmp = prev; prev = cur; cur = tmp
        }
        return prev[b.size]
    }
}
