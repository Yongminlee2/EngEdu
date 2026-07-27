package com.piyak.english.engine

import kotlin.math.cos
import kotlin.math.sin

/** 정규화 좌표(0~1). y는 아래로 증가. */
data class Pt(val x: Float, val y: Float)

/**
 * 글자 한 개의 쓰기 데이터.
 * 획(stroke)은 "중심선" 폴리라인이다 — 아이가 따라 그릴 길이자, 병아리가 걸어갈 길.
 * 획의 순서와 점의 순서가 곧 쓰는 순서·방향이 된다.
 */
data class LetterDef(
    val upper: Char,
    val lower: Char,
    val emoji: String,
    val word: String,
    val ko: String,
    val upperStrokes: List<List<Pt>>,
    val lowerStrokes: List<List<Pt>>,
) {
    fun strokes(uppercase: Boolean) = if (uppercase) upperStrokes else lowerStrokes
    fun glyph(uppercase: Boolean) = if (uppercase) upper else lower
}

private fun p(x: Double, y: Double) = Pt(x.toFloat(), y.toFloat())

/** 직선 한 획 */
private fun ln(x1: Double, y1: Double, x2: Double, y2: Double) = listOf(p(x1, y1), p(x2, y2))

/** 꺾은선 한 획 — x,y 를 번갈아 나열 */
private fun poly(vararg xy: Double): List<Pt> =
    (xy.indices step 2).map { p(xy[it], xy[it + 1]) }

/**
 * 타원 호. 각도는 0°=오른쪽, 90°=아래, 180°=왼쪽, 270°=위 (화면 좌표라 y가 아래로 증가).
 * sweep 이 양수면 화면상 시계 방향, 음수면 반시계 방향.
 */
private fun arc(
    cx: Double, cy: Double, rx: Double, ry: Double,
    startDeg: Double, sweepDeg: Double, steps: Int = 20,
): List<Pt> = (0..steps).map { i ->
    val a = Math.toRadians(startDeg + sweepDeg * i / steps)
    p(cx + rx * cos(a), cy + ry * sin(a))
}

/** 두 획 데이터를 이어 붙여 한 획으로 (직선 + 곡선 조합) */
private operator fun List<Pt>.plus(other: List<Pt>): List<Pt> = ArrayList(this).apply { addAll(other) }

object Letters {

    val ALL: List<LetterDef> = listOf(
        LetterDef(
            'A', 'a', "🍎", "Apple", "사과",
            listOf(
                ln(0.50, 0.12, 0.18, 0.88),
                ln(0.50, 0.12, 0.82, 0.88),
                ln(0.29, 0.62, 0.71, 0.62),
            ),
            listOf(
                arc(0.48, 0.66, 0.20, 0.22, 0.0, -360.0),
                ln(0.68, 0.45, 0.68, 0.88),
            ),
        ),
        LetterDef(
            'B', 'b', "🐻", "Bear", "곰",
            listOf(
                ln(0.25, 0.12, 0.25, 0.88),
                arc(0.25, 0.30, 0.32, 0.18, 270.0, 180.0),
                arc(0.25, 0.68, 0.36, 0.20, 270.0, 180.0),
            ),
            listOf(
                ln(0.28, 0.12, 0.28, 0.88),
                arc(0.28, 0.66, 0.24, 0.22, 270.0, 180.0),
            ),
        ),
        LetterDef(
            'C', 'c', "🐱", "Cat", "고양이",
            listOf(arc(0.50, 0.50, 0.32, 0.38, 315.0, -270.0)),
            listOf(arc(0.50, 0.66, 0.22, 0.22, 315.0, -270.0)),
        ),
        LetterDef(
            'D', 'd', "🐶", "Dog", "강아지",
            listOf(
                ln(0.25, 0.12, 0.25, 0.88),
                arc(0.25, 0.50, 0.40, 0.38, 270.0, 180.0),
            ),
            listOf(
                arc(0.48, 0.66, 0.20, 0.22, 0.0, -360.0),
                ln(0.68, 0.12, 0.68, 0.88),
            ),
        ),
        LetterDef(
            'E', 'e', "🐘", "Elephant", "코끼리",
            listOf(
                ln(0.28, 0.12, 0.28, 0.88),
                ln(0.28, 0.12, 0.76, 0.12),
                ln(0.28, 0.50, 0.68, 0.50),
                ln(0.28, 0.88, 0.76, 0.88),
            ),
            listOf(poly(0.28, 0.68, 0.72, 0.68) + arc(0.50, 0.66, 0.22, 0.22, 0.0, -260.0)),
        ),
        LetterDef(
            'F', 'f', "🐸", "Frog", "개구리",
            listOf(
                ln(0.28, 0.12, 0.28, 0.88),
                ln(0.28, 0.12, 0.76, 0.12),
                ln(0.28, 0.50, 0.68, 0.50),
            ),
            listOf(
                arc(0.58, 0.26, 0.16, 0.14, 0.0, -180.0) + poly(0.42, 0.88),
                ln(0.26, 0.50, 0.62, 0.50),
            ),
        ),
        LetterDef(
            'G', 'g', "🍇", "Grapes", "포도",
            listOf(
                arc(0.50, 0.50, 0.32, 0.38, 315.0, -290.0) + poly(0.79, 0.50),
                ln(0.79, 0.50, 0.55, 0.50),
            ),
            listOf(
                arc(0.48, 0.66, 0.20, 0.22, 0.0, -360.0),
                poly(0.68, 0.45, 0.68, 0.92) + arc(0.50, 0.92, 0.18, 0.12, 0.0, 140.0),
            ),
        ),
        LetterDef(
            'H', 'h', "🏠", "House", "집",
            listOf(
                ln(0.25, 0.12, 0.25, 0.88),
                ln(0.75, 0.12, 0.75, 0.88),
                ln(0.25, 0.50, 0.75, 0.50),
            ),
            listOf(
                ln(0.28, 0.12, 0.28, 0.88),
                arc(0.50, 0.66, 0.22, 0.20, 180.0, 180.0) + poly(0.72, 0.88),
            ),
        ),
        LetterDef(
            'I', 'i', "🍦", "Ice cream", "아이스크림",
            listOf(
                ln(0.50, 0.12, 0.50, 0.88),
                ln(0.32, 0.12, 0.68, 0.12),
                ln(0.32, 0.88, 0.68, 0.88),
            ),
            listOf(
                ln(0.50, 0.45, 0.50, 0.88),
                arc(0.50, 0.28, 0.06, 0.06, 270.0, -360.0, 12),
            ),
        ),
        LetterDef(
            'J', 'j', "🧃", "Juice", "주스",
            listOf(
                poly(0.62, 0.12, 0.62, 0.68) + arc(0.42, 0.68, 0.20, 0.20, 0.0, 140.0),
                ln(0.42, 0.12, 0.80, 0.12),
            ),
            listOf(
                poly(0.55, 0.45, 0.55, 0.90) + arc(0.40, 0.90, 0.15, 0.12, 0.0, 140.0),
                arc(0.55, 0.28, 0.06, 0.06, 270.0, -360.0, 12),
            ),
        ),
        LetterDef(
            'K', 'k', "🔑", "Key", "열쇠",
            listOf(
                ln(0.25, 0.12, 0.25, 0.88),
                ln(0.75, 0.12, 0.28, 0.52),
                ln(0.38, 0.44, 0.78, 0.88),
            ),
            listOf(
                ln(0.28, 0.12, 0.28, 0.88),
                ln(0.68, 0.50, 0.32, 0.70),
                ln(0.42, 0.63, 0.72, 0.88),
            ),
        ),
        LetterDef(
            'L', 'l', "🦁", "Lion", "사자",
            listOf(poly(0.30, 0.12, 0.30, 0.88, 0.76, 0.88)),
            listOf(ln(0.50, 0.12, 0.50, 0.88)),
        ),
        LetterDef(
            'M', 'm', "🌙", "Moon", "달",
            listOf(poly(0.20, 0.88, 0.20, 0.12, 0.50, 0.62, 0.80, 0.12, 0.80, 0.88)),
            listOf(
                ln(0.24, 0.45, 0.24, 0.88),
                arc(0.36, 0.62, 0.12, 0.17, 180.0, 180.0) + poly(0.48, 0.88),
                arc(0.60, 0.62, 0.12, 0.17, 180.0, 180.0) + poly(0.72, 0.88),
            ),
        ),
        LetterDef(
            'N', 'n', "📓", "Notebook", "공책",
            listOf(poly(0.25, 0.88, 0.25, 0.12, 0.75, 0.88, 0.75, 0.12)),
            listOf(
                ln(0.28, 0.45, 0.28, 0.88),
                arc(0.50, 0.64, 0.22, 0.19, 180.0, 180.0) + poly(0.72, 0.88),
            ),
        ),
        LetterDef(
            'O', 'o', "🍊", "Orange", "오렌지",
            listOf(arc(0.50, 0.50, 0.33, 0.38, 270.0, -360.0, 24)),
            listOf(arc(0.50, 0.66, 0.22, 0.22, 270.0, -360.0, 20)),
        ),
        LetterDef(
            'P', 'p', "🐧", "Penguin", "펭귄",
            listOf(
                ln(0.25, 0.12, 0.25, 0.88),
                arc(0.25, 0.31, 0.34, 0.19, 270.0, 180.0),
            ),
            listOf(
                ln(0.28, 0.45, 0.28, 1.00),
                arc(0.28, 0.66, 0.22, 0.22, 270.0, 180.0),
            ),
        ),
        LetterDef(
            'Q', 'q', "👑", "Queen", "여왕",
            listOf(
                arc(0.50, 0.50, 0.33, 0.38, 270.0, -360.0, 24),
                ln(0.62, 0.68, 0.86, 0.94),
            ),
            listOf(
                arc(0.48, 0.66, 0.20, 0.22, 0.0, -360.0),
                ln(0.68, 0.45, 0.68, 1.00),
            ),
        ),
        LetterDef(
            'R', 'r', "🌈", "Rainbow", "무지개",
            listOf(
                ln(0.25, 0.12, 0.25, 0.88),
                arc(0.25, 0.31, 0.34, 0.19, 270.0, 180.0),
                ln(0.35, 0.50, 0.78, 0.88),
            ),
            listOf(
                ln(0.32, 0.45, 0.32, 0.88),
                arc(0.52, 0.62, 0.20, 0.17, 180.0, 120.0),
            ),
        ),
        LetterDef(
            'S', 's', "☀️", "Sun", "해",
            listOf(
                poly(
                    0.75, 0.22, 0.60, 0.13, 0.40, 0.13, 0.28, 0.22, 0.28, 0.35,
                    0.40, 0.45, 0.60, 0.55, 0.72, 0.65, 0.72, 0.78, 0.60, 0.87,
                    0.40, 0.87, 0.25, 0.78,
                )
            ),
            listOf(
                poly(
                    0.713, 0.507, 0.585, 0.456, 0.415, 0.456, 0.313, 0.507, 0.313, 0.580,
                    0.415, 0.637, 0.585, 0.693, 0.687, 0.750, 0.687, 0.823, 0.585, 0.874,
                    0.415, 0.874, 0.288, 0.823,
                )
            ),
        ),
        LetterDef(
            'T', 't', "🐯", "Tiger", "호랑이",
            listOf(
                ln(0.20, 0.12, 0.80, 0.12),
                ln(0.50, 0.12, 0.50, 0.88),
            ),
            listOf(
                poly(0.45, 0.20, 0.45, 0.78) + arc(0.57, 0.78, 0.12, 0.10, 180.0, -90.0),
                ln(0.28, 0.45, 0.62, 0.45),
            ),
        ),
        LetterDef(
            'U', 'u', "☂️", "Umbrella", "우산",
            listOf(poly(0.25, 0.12, 0.25, 0.60) + arc(0.50, 0.60, 0.25, 0.28, 180.0, -180.0) + poly(0.75, 0.12)),
            listOf(
                poly(0.28, 0.45, 0.28, 0.70) + arc(0.50, 0.70, 0.22, 0.18, 180.0, -180.0) + poly(0.72, 0.45),
                ln(0.72, 0.45, 0.72, 0.88),
            ),
        ),
        LetterDef(
            'V', 'v', "🎻", "Violin", "바이올린",
            listOf(poly(0.22, 0.12, 0.50, 0.88, 0.78, 0.12)),
            listOf(poly(0.28, 0.45, 0.50, 0.88, 0.72, 0.45)),
        ),
        LetterDef(
            'W', 'w', "🍉", "Watermelon", "수박",
            listOf(poly(0.16, 0.12, 0.33, 0.88, 0.50, 0.35, 0.67, 0.88, 0.84, 0.12)),
            listOf(poly(0.22, 0.45, 0.36, 0.88, 0.50, 0.55, 0.64, 0.88, 0.78, 0.45)),
        ),
        LetterDef(
            'X', 'x', "🎄", "Xmas tree", "크리스마스트리",
            listOf(
                ln(0.22, 0.12, 0.78, 0.88),
                ln(0.78, 0.12, 0.22, 0.88),
            ),
            listOf(
                ln(0.28, 0.45, 0.72, 0.88),
                ln(0.72, 0.45, 0.28, 0.88),
            ),
        ),
        LetterDef(
            'Y', 'y', "🪀", "Yo-yo", "요요",
            listOf(
                poly(0.22, 0.12, 0.50, 0.50, 0.50, 0.88),
                ln(0.78, 0.12, 0.50, 0.50),
            ),
            listOf(
                ln(0.28, 0.45, 0.50, 0.85),
                ln(0.72, 0.45, 0.42, 1.00),
            ),
        ),
        LetterDef(
            'Z', 'z', "🦓", "Zebra", "얼룩말",
            listOf(poly(0.22, 0.12, 0.78, 0.12, 0.22, 0.88, 0.78, 0.88)),
            listOf(poly(0.28, 0.45, 0.72, 0.45, 0.28, 0.88, 0.72, 0.88)),
        ),
    )

    fun byIndex(i: Int): LetterDef = ALL[i.coerceIn(0, ALL.size - 1)]

    /** 진행도 저장 키: A_U / a_L */
    fun key(def: LetterDef, uppercase: Boolean): String =
        "${def.glyph(uppercase)}_${if (uppercase) "U" else "L"}"

    /** 글자 하나를 다 쓰면 주는 XP */
    const val XP_PER_LETTER = 5
}
