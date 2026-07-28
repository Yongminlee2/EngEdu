package com.piyak.english.model

import org.json.JSONArray
import org.json.JSONObject

/**
 * 수학 문제에 붙는 "그림 명세". 이미지 파일 없이 이모지와 Canvas 로 그린다.
 * 새 그림이 필요하면 kind 를 늘리고 MathVisualView 에 그리는 법만 추가하면 된다.
 */
data class MathVisual(
    val kind: String,
    /** 이모지 하나 (emoji / emoji_op / array 에서 사용) */
    val emoji: String = "🍎",
    /** 개수 (emoji), 왼쪽 개수 (emoji_op), 행 (array) */
    val a: Int = 0,
    /** 오른쪽 개수 (emoji_op), 열 (array) */
    val bb: Int = 0,
    /** 연산 기호 (emoji_op): + 또는 - */
    val op: String = "+",
    /** 도형 이름들 (shapes) / 막대 이름들 (bar_graph) */
    val labels: List<String> = emptyList(),
    /** 막대 값들 (bar_graph), 수직선 표시 위치 (number_line) */
    val values: List<Double> = emptyList(),
    /** 분자 (fraction), 시(clock), 각도(angle), 수직선 최소(number_line) */
    val p: Double = 0.0,
    /** 분모 (fraction), 분(clock), 수직선 최대(number_line) */
    val q: Double = 1.0,
    /** 끌어 옮길 사물들 (shape_sort) */
    val items: List<String> = emptyList(),
    /** items 각각이 들어가야 할 바구니 번호 (shape_sort) */
    val kinds: List<Int> = emptyList(),
) {
    companion object {
        const val EMOJI = "emoji"
        const val EMOJI_OP = "emoji_op"
        const val ARRAY = "array"
        const val SHAPES = "shapes"
        const val CLOCK = "clock"
        const val FRACTION = "fraction"
        const val NUMBER_LINE = "number_line"
        const val BAR_GRAPH = "bar_graph"
        const val ANGLE = "angle"
        const val COMPARE = "compare"

        /** 바늘을 돌려 시각을 맞추는 시계 (p·q = 정답 시·분) */
        const val CLOCK_SET = "clock_set"

        /** 사물을 끌어다 묶음에 나눠 담기 (a = 전체 개수, b = 묶음 수) */
        const val GROUP = "group"

        /** 조각을 탭해서 분수만큼 색칠하기 (p = 목표 분자, q = 분모) */
        const val FRACTION_PAINT = "fraction_paint"

        /** 도형을 이름 붙은 바구니로 끌어 분류하기 (items·kinds·labels) */
        const val SHAPE_SORT = "shape_sort"

        /** 수직선 위의 점을 끌어 수를 찾기 (p·q = 왼쪽·오른쪽 끝, a = 구간 수) */
        const val NUMBER_LINE_DRAG = "number_line_drag"

        /** 반직선을 돌려 각도를 만들기 (p = 목표 각도) */
        const val ANGLE_SET = "angle_set"

        /** 양팔 저울을 평형으로 만들기 (a·x + b = p 에서 x 를 찾는다) */
        const val BALANCE = "balance"

        /** 막대를 끌어 올려 그래프 완성하기 (labels = 항목, values = 목표 높이) */
        const val BAR_BUILD = "bar_build"

        val KINDS = setOf(
            EMOJI, EMOJI_OP, ARRAY, SHAPES, CLOCK, FRACTION,
            NUMBER_LINE, BAR_GRAPH, ANGLE, COMPARE,
            CLOCK_SET, GROUP, FRACTION_PAINT, SHAPE_SORT,
            NUMBER_LINE_DRAG, ANGLE_SET, BALANCE, BAR_BUILD,
        )

        /** 그림 자체가 답을 입력받는 종류 (키패드·보기가 필요 없다) */
        val INPUT_KINDS = setOf(
            CLOCK_SET, GROUP, FRACTION_PAINT, SHAPE_SORT,
            NUMBER_LINE_DRAG, ANGLE_SET, BALANCE, BAR_BUILD,
        )

        fun fromJson(o: JSONObject?): MathVisual? {
            if (o == null) return null
            val kind = o.optString("kind")
            if (kind.isEmpty() || kind !in KINDS) return null
            return MathVisual(
                kind = kind,
                emoji = o.optString("emoji", "🍎"),
                a = o.optInt("a", 0),
                bb = o.optInt("b", 0),
                op = o.optString("op", "+"),
                labels = strList(o.optJSONArray("labels")),
                values = numList(o.optJSONArray("values")),
                p = o.optDouble("p", 0.0),
                q = o.optDouble("q", 1.0),
                items = strList(o.optJSONArray("items")),
                kinds = intList(o.optJSONArray("kinds")),
            )
        }

        private fun strList(a: JSONArray?): List<String> =
            if (a == null) emptyList() else (0 until a.length()).map { a.getString(it) }

        private fun numList(a: JSONArray?): List<Double> =
            if (a == null) emptyList() else (0 until a.length()).map { a.getDouble(it) }

        private fun intList(a: JSONArray?): List<Int> =
            if (a == null) emptyList() else (0 until a.length()).map { a.getInt(it) }
    }
}
