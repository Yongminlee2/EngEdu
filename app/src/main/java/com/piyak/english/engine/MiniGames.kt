package com.piyak.english.engine

import com.piyak.english.R
import com.piyak.english.model.Subject
import kotlin.random.Random

/** 미니게임 한 종류 */
data class GameDef(
    val id: String,
    val emoji: String,
    /** 이름·설명은 문자열 리소스 id — 폰 언어를 따라간다 */
    val titleRes: Int,
    val descRes: Int,
    val subject: Subject,
    val color: String,
)

/** 게임에서 내는 한 문제 — 물음과 보기(정답 하나 + 오답들) */
data class GameRound(
    val question: String,
    /**
     * 물음을 **폰 언어로** 다시 만들 때 쓰는 뼈대와 값.
     * MiniGames 는 Context 가 없는 순수 로직이라 여기서는 한국어 원문만 만들고,
     * 화면(GameActivity)이 이 두 값으로 번역문을 조립한다. 0 이면 원문을 그대로 쓴다.
     */
    val questionRes: Int = 0,
    val questionArgs: List<String> = emptyList(),
    /** 화면에 띄울 항목들. 정답은 answer 와 같은 문자열 */
    val options: List<String>,
    val answer: String,
    /** 소리로 읽어 줄 말 (없으면 question 을 읽는다) */
    val speak: String? = null,
    /** 크게 보여줄 그림 */
    val emoji: String? = null,
)

object MiniGames {

    const val BALLOON = "balloon"
    const val BASKET = "basket"
    const val LINE = "line"

    val ALL = listOf(
        GameDef(
            BALLOON, "🎈", R.string.game_balloon,
            R.string.game_balloon_math_d, Subject.MATH, "#FFCDD2"
        ),
        GameDef(
            BASKET, "🧺", R.string.game_basket,
            R.string.game_basket_d, Subject.MATH, "#C8E6C9"
        ),
        GameDef(
            LINE, "🔗", R.string.game_line,
            R.string.game_line_math_d, Subject.MATH, "#B3E5FC"
        ),
        GameDef(
            "${BALLOON}_en", "🎈", R.string.game_balloon,
            R.string.game_balloon_en_d, Subject.ENGLISH, "#FFCDD2"
        ),
        GameDef(
            "${LINE}_en", "🔗", R.string.game_line,
            R.string.game_line_en_d, Subject.ENGLISH, "#B3E5FC"
        ),
    )

    fun forSubject(s: Subject): List<GameDef> = ALL.filter { it.subject == s }

    fun byId(id: String): GameDef? = ALL.firstOrNull { it.id == id }

    // ---------------- 낱말 데이터 (영어 게임용) ----------------
    /** (이모지, 영어, 뜻) */
    val WORDS = listOf(
        Triple("🍎", "apple", "사과"), Triple("🍌", "banana", "바나나"),
        Triple("🍓", "strawberry", "딸기"), Triple("🍊", "orange", "오렌지"),
        Triple("🐶", "dog", "개"), Triple("🐱", "cat", "고양이"),
        Triple("🐰", "rabbit", "토끼"), Triple("🐻", "bear", "곰"),
        Triple("🐷", "pig", "돼지"), Triple("🐸", "frog", "개구리"),
        Triple("🐧", "penguin", "펭귄"), Triple("🦁", "lion", "사자"),
        Triple("🚗", "car", "자동차"), Triple("🚌", "bus", "버스"),
        Triple("✈️", "airplane", "비행기"), Triple("🚲", "bicycle", "자전거"),
        Triple("🏠", "house", "집"), Triple("🏫", "school", "학교"),
        Triple("🌳", "tree", "나무"), Triple("🌸", "flower", "꽃"),
        Triple("⭐", "star", "별"), Triple("🌙", "moon", "달"),
        Triple("☀️", "sun", "해"), Triple("🌈", "rainbow", "무지개"),
        Triple("📚", "book", "책"), Triple("✏️", "pencil", "연필"),
        Triple("👟", "shoes", "신발"), Triple("🎒", "backpack", "가방"),
        Triple("🍪", "cookie", "쿠키"), Triple("🥛", "milk", "우유"),
    )

    /** 수 세기용 사물 */
    val THINGS = listOf("🍎", "🍓", "⭐", "🎈", "🍪", "🐥", "🌸", "🐟", "🚗", "🧸")

    // ---------------- 라운드 생성 ----------------

    /**
     * 풍선 게임 라운드.
     * @param level 1~5 (커질수록 큰 수·곱셈까지)
     */
    fun balloonMath(level: Int, rnd: Random = Random.Default): GameRound {
        val max = when (level) {
            1 -> 5; 2 -> 9; 3 -> 20; 4 -> 50; else -> 99
        }
        val kind = if (level >= 3 && rnd.nextInt(3) == 0) "×" else if (rnd.nextBoolean()) "+" else "-"
        val (q, ans) = when (kind) {
            "×" -> {
                val a = rnd.nextInt(2, 10)
                val b = rnd.nextInt(2, 10)
                "$a × $b" to a * b
            }
            "+" -> {
                val a = rnd.nextInt(1, max)
                val b = rnd.nextInt(1, max)
                "$a + $b" to a + b
            }
            else -> {
                val a = rnd.nextInt(2, max + 1)
                val b = rnd.nextInt(1, a)
                "$a - $b" to a - b
            }
        }
        return GameRound(
            question = "$q = ?",
            options = wrongNumbers(ans, 5, rnd).map { it.toString() },
            answer = ans.toString(),
            speak = null,
        )
    }

    /** 영어 풍선: 낱말을 듣고 맞는 그림 고르기 */
    fun balloonEnglish(rnd: Random = Random.Default): GameRound {
        val pool = WORDS.shuffled(rnd)
        val target = pool.first()
        val options = (listOf(target) + pool.drop(1).take(5)).shuffled(rnd)
        return GameRound(
            question = "${target.second} 를 찾아 터뜨려요!",
            questionRes = R.string.game_q_balloon,
            questionArgs = listOf(target.second),
            options = options.map { it.first },
            answer = target.first,
            speak = target.second,
        )
    }

    /** 바구니 담기: n개 담기 */
    fun basketRound(level: Int, rnd: Random = Random.Default): GameRound {
        val n = when (level) {
            1 -> rnd.nextInt(1, 6)
            2 -> rnd.nextInt(3, 10)
            else -> rnd.nextInt(5, 16)
        }
        val thing = THINGS.random(rnd)
        return GameRound(
            question = "${thing} 를 $n 개 담아요",
            questionRes = R.string.game_q_basket,
            questionArgs = listOf(thing, n.toString()),
            options = listOf(thing),
            answer = n.toString(),
            speak = "$n 개 담아 보세요",
            emoji = thing,
        )
    }

    /** 선 잇기(수학): 식 ↔ 답 4쌍 */
    fun lineMath(level: Int, rnd: Random = Random.Default): List<Pair<String, String>> {
        val used = HashSet<Int>()
        val out = ArrayList<Pair<String, String>>()
        var guard = 0
        while (out.size < 4 && guard++ < 100) {
            val r = balloonMath(level, rnd)
            val ans = r.answer.toInt()
            if (!used.add(ans)) continue
            out.add(r.question.removeSuffix(" = ?") to r.answer)
        }
        return out
    }

    /** 선 잇기(영어): 그림 ↔ 낱말 4쌍 */
    fun lineEnglish(rnd: Random = Random.Default): List<Pair<String, String>> =
        WORDS.shuffled(rnd).take(4).map { it.first to it.second }

    /** 정답 주변의 그럴듯한 오답 n개 (중복·음수 없음) */
    fun wrongNumbers(answer: Int, n: Int, rnd: Random = Random.Default): List<Int> {
        val set = LinkedHashSet<Int>()
        set.add(answer)
        var d = 1
        while (set.size < n && d < 60) {
            for (w in listOf(answer + d, answer - d)) {
                if (w >= 0 && set.size < n) set.add(w)
            }
            d++
        }
        return set.toList().shuffled(rnd)
    }
}

/** 게임 결과 → 보상. 게임으로 용돈을 무한히 벌 수 없게 하루 판수를 제한한다. */
object GameReward {
    /** 하루에 용돈을 받을 수 있는 판 수 */
    const val DAILY_PAID_ROUNDS = 3

    /** 한 판 최대 용돈 */
    const val MAX_COINS = 20

    /** 정답 하나당 점수 */
    const val SCORE_PER_HIT = 10

    /** 점수 → 용돈 (만점에 가까울수록 많이, 최대 MAX_COINS) */
    fun coinsFor(score: Int, maxScore: Int): Int {
        if (maxScore <= 0) return 0
        val ratio = score.toFloat() / maxScore
        return (MAX_COINS * ratio).toInt().coerceIn(0, MAX_COINS)
    }

    /** 점수 → XP */
    fun xpFor(score: Int): Int = (score / 10).coerceIn(0, 30)

    /** 별점 (결과 화면 표시용) */
    fun stars(score: Int, maxScore: Int): Int = when {
        maxScore <= 0 -> 0
        score >= maxScore -> 3
        score >= maxScore * 0.7f -> 2
        score > 0 -> 1
        else -> 0
    }
}
