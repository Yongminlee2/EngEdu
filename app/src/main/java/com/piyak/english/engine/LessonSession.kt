package com.piyak.english.engine

import com.piyak.english.model.Question

/**
 * 레슨 한 판의 진행 상태. 순수 로직(안드로이드 의존 없음) — 단위테스트 대상.
 * 듀오링고 방식: 틀린 문제는 큐 끝에 재출제. 하트 0이면 실패.
 */
class LessonSession(
    questions: List<Question>,
    var hearts: Int,
    val useHearts: Boolean = true,
) {
    private val queue = ArrayDeque(questions)
    private val total = questions.size
    private var solved = 0
    private val firstTryWrong = HashSet<String>()
    val wrongIds = LinkedHashSet<String>()

    var failed = false
        private set

    fun current(): Question? = queue.firstOrNull()

    val isFinished: Boolean get() = queue.isEmpty() || failed

    /** 0.0 ~ 1.0 진행률 (고유 문제 기준) */
    val progress: Float get() = if (total == 0) 1f else solved.toFloat() / total

    val totalCount: Int get() = total

    /** 정답 처리 → true 반환. 오답이면 재출제 큐잉 + 하트 차감 → false. */
    fun submit(correct: Boolean): Boolean {
        val q = queue.removeFirstOrNull() ?: return correct
        if (correct) {
            solved++
            return true
        }
        firstTryWrong.add(q.id)
        wrongIds.add(q.id)
        if (useHearts) {
            hearts--
            if (hearts <= 0) failed = true
        }
        queue.addLast(q)
        return false
    }

    /**
     * 재출제·하트 차감 없이 넘어가는 제출 (매칭 문제, 말하기 건너뛰기).
     * correct=false 면 퍼펙트만 깨진다.
     */
    fun submitNoPenalty(correct: Boolean) {
        val q = queue.removeFirstOrNull() ?: return
        solved++
        if (!correct) firstTryWrong.add(q.id)
    }

    /** 첫 시도에 다 맞았는지 */
    val isPerfect: Boolean get() = firstTryWrong.isEmpty()

    /** 첫 시도 정답 수 */
    val firstTryCorrect: Int get() = total - firstTryWrong.size

    /** 정답률 (첫 시도 기준) */
    val accuracy: Float get() = if (total == 0) 1f else firstTryCorrect.toFloat() / total

    /** 획득 XP: 첫시도 정답당 2 + 완료 10 + 퍼펙트 5 */
    fun xpEarned(): Int {
        if (failed) return 0
        var xp = firstTryCorrect * 2 + 10
        if (isPerfect) xp += 5
        return xp
    }

    /** 별점 1~3 (첫 시도 정답률) */
    fun stars(): Int = when {
        isPerfect -> 3
        accuracy >= 0.8f -> 2
        else -> 1
    }
}
