package com.piyak.english.model

/** 과목. 트랙 목록·실력 영역·색을 과목별로 알려 준다. */
enum class Subject(
    val id: String,
    val emoji: String,
    val title: String,
    val subtitle: String,
    val color: String,
) {
    ENGLISH(
        "english", "📘", "영어",
        "듣기 · 말하기 · 읽기 · 쓰기", "#AEDCF5"
    ),
    MATH(
        "math", "🔢", "수학",
        "유치원부터 고3까지 차근차근", "#F7C6C7"
    );

    /** 이 과목의 트랙 id 목록 (팩 파일명과 같다) */
    val tracks: List<String>
        get() = when (this) {
            ENGLISH -> listOf(
                "elem",
                "basic", "daily", "toeic", "toefl",
                "listening", "speaking", "writing", "grammar", "reading",
            )
            MATH -> MathGrades.ALL.map { it.trackId }
        }

    companion object {
        fun of(id: String): Subject = entries.firstOrNull { it.id == id } ?: ENGLISH
    }
}

/** 수학 학년 한 칸 */
data class MathGrade(
    val trackId: String,
    val emoji: String,
    val title: String,
    val subtitle: String,
    val stage: String,
    val color: String,
)

object MathGrades {
    const val STAGE_ELEM = "유치원 · 초등"
    const val STAGE_MID = "중학교"
    const val STAGE_HIGH = "고등학교"

    val ALL: List<MathGrade> = listOf(
        MathGrade("math_k", "🐣", "유치원", "수 세기 · 모양 · 크기 비교", STAGE_ELEM, "#FFE0B2"),
        MathGrade("math_g1", "1️⃣", "초등 1학년", "100까지의 수 · 덧셈 뺄셈 · 시계", STAGE_ELEM, "#FFECB3"),
        MathGrade("math_g2", "2️⃣", "초등 2학년", "세 자리 수 · 곱셈구구 · 길이", STAGE_ELEM, "#F0F4C3"),
        MathGrade("math_g3", "3️⃣", "초등 3학년", "나눗셈 · 분수와 소수 · 도형", STAGE_ELEM, "#DCEDC8"),
        MathGrade("math_g4", "4️⃣", "초등 4학년", "큰 수 · 각도 · 그래프", STAGE_ELEM, "#C8E6C9"),
        MathGrade("math_g5", "5️⃣", "초등 5학년", "약수와 배수 · 분수 계산 · 넓이", STAGE_ELEM, "#B2DFDB"),
        MathGrade("math_g6", "6️⃣", "초등 6학년", "비와 비율 · 부피 · 원의 넓이", STAGE_ELEM, "#B3E5FC"),
        MathGrade("math_m1", "🌱", "중학교 1학년", "정수와 유리수 · 일차방정식 · 도형", STAGE_MID, "#BBDEFB"),
        MathGrade("math_m2", "🌿", "중학교 2학년", "연립방정식 · 일차함수 · 확률", STAGE_MID, "#C5CAE9"),
        MathGrade("math_m3", "🍀", "중학교 3학년", "이차방정식 · 이차함수 · 삼각비", STAGE_MID, "#D1C4E9"),
        MathGrade("math_h1", "🌳", "고등학교 1학년", "다항식 · 도형의 방정식 · 순열조합", STAGE_HIGH, "#E1BEE7"),
        MathGrade("math_h2", "🌲", "고등학교 2학년", "지수로그 · 삼각함수 · 미분과 적분", STAGE_HIGH, "#F8BBD0"),
        MathGrade("math_h3", "🎓", "고등학교 3학년", "미적분 · 확률과 통계 · 기하", STAGE_HIGH, "#FFCDD2"),
    )

    val STAGES = listOf(STAGE_ELEM, STAGE_MID, STAGE_HIGH)

    fun of(trackId: String): MathGrade? = ALL.firstOrNull { it.trackId == trackId }

    fun byStage(stage: String): List<MathGrade> = ALL.filter { it.stage == stage }

    /** 배치고사 레벨(1~13) → 트랙 */
    fun forLevel(level: Int): MathGrade = ALL[(level - 1).coerceIn(0, ALL.size - 1)]

    fun levelOf(trackId: String): Int = ALL.indexOfFirst { it.trackId == trackId } + 1
}
