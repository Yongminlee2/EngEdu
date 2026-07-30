package com.piyak.english

import com.piyak.english.engine.Letters
import com.piyak.english.engine.Pt
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

/**
 * 알파벳 따라쓰기 획 데이터 검사.
 *
 * 화면이 팅긴다는 제보를 받고 만들었다. 따라쓰기 판(`TraceView`)은 획을 일정 간격으로
 * 리샘플링해 "체크포인트"를 만들고, 그 첫 점에 시작 번호를 그린다.
 * **점이 없는 획이 하나라도 있으면 그 첫 점을 꺼내다 죽는다.**
 * 그래서 여기서 52글자 전체를 뷰와 같은 계산으로 돌려 본다.
 */
class LetterStrokeTest {

    /** TraceView.resample 과 같은 계산 (여기서 깨지면 화면에서도 깨진다) */
    private fun resample(pts: List<Pt>, spacing: Float): List<Pt> {
        if (pts.size < 2) return pts
        val out = ArrayList<Pt>()
        out.add(pts[0])
        var carry = 0f
        for (i in 0 until pts.size - 1) {
            val a = pts[i]
            val b = pts[i + 1]
            val seg = hypot(b.x - a.x, b.y - a.y)
            if (seg <= 0.0001f) continue
            var d = spacing - carry
            while (d <= seg) {
                val t = d / seg
                out.add(Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t))
                d += spacing
            }
            carry = seg - (d - spacing)
        }
        if (out.last() != pts.last()) out.add(pts.last())
        return out
    }

    private fun length(pts: List<Pt>): Float {
        var sum = 0f
        for (i in 0 until pts.size - 1) {
            sum += hypot(pts[i + 1].x - pts[i].x, pts[i + 1].y - pts[i].y)
        }
        return sum
    }

    @Test fun everyStrokeCanBeTraced() {
        // 뷰에서 쓰는 값과 같은 비율 (박스 크기의 3.5%)
        val spacing = 0.035f
        var checked = 0
        for (d in Letters.ALL) for (upper in listOf(true, false)) {
            val strokes = d.strokes(upper)
            val name = "${d.glyph(upper)}(${if (upper) "대" else "소"})"
            assertTrue("$name: 획이 하나도 없다", strokes.isNotEmpty())
            strokes.forEachIndexed { i, s ->
                assertTrue("$name ${i + 1}번 획: 점이 2개 미만이라 그릴 수 없다", s.size >= 2)
                assertTrue(
                    "$name ${i + 1}번 획: 길이가 0이라 시작점만 있고 갈 곳이 없다",
                    length(s) > 0.001f
                )
                val rs = resample(s, spacing)
                // 체크포인트가 비면 시작 번호를 그릴 때 첫 점을 꺼내다 죽는다
                assertTrue("$name ${i + 1}번 획: 체크포인트가 비었다", rs.isNotEmpty())
                assertTrue("$name ${i + 1}번 획: 체크포인트가 너무 적다", rs.size >= 2)
                checked++
            }
        }
        println("검사한 획: $checked (글자 ${Letters.ALL.size * 2}개)")
        assertTrue("검사된 획이 너무 적다", checked >= Letters.ALL.size * 2)
    }

    /**
     * 획이 글자 칸을 크게 벗어나면 화면 밖에 그려져 따라 그릴 수 없다.
     * g·j·p·q·y 의 꼬리는 기준선 아래로 내려가는 게 정상이라 아래쪽만 넉넉히 본다
     * (뷰가 10% 여백을 두고 그리므로 그 안에 들어온다).
     */
    @Test fun everyStrokeStaysInsideTheBox() {
        for (d in Letters.ALL) for (upper in listOf(true, false)) {
            val name = "${d.glyph(upper)}(${if (upper) "대" else "소"})"
            for ((i, s) in d.strokes(upper).withIndex()) {
                for (p in s) {
                    assertTrue(
                        "$name ${i + 1}번 획: 점이 칸 밖에 있다 (${p.x}, ${p.y})",
                        p.x >= -0.05f && p.x <= 1.05f && p.y >= -0.05f && p.y <= 1.10f
                    )
                }
            }
        }
    }

    /**
     * 획이 너무 짧으면 판정 오차(박스의 13%)보다 작아서 한 번만 스쳐도 완성된다.
     * "따라 썼다"고 볼 수 없으므로 그런 획이 있으면 안 된다.
     */
    @Test fun noStrokeIsShorterThanTheTouchTolerance() {
        val tol = 0.13f
        val tooShort = ArrayList<String>()
        for (d in Letters.ALL) for (upper in listOf(true, false)) {
            for ((i, s) in d.strokes(upper).withIndex()) {
                val len = length(s)
                if (len < tol) {
                    tooShort.add("${d.glyph(upper)}${if (upper) "대" else "소"}-${i + 1}획(${"%.3f".format(len)})")
                }
            }
        }
        assertTrue("스쳐도 완성되는 짧은 획: $tooShort", tooShort.isEmpty())
    }
}
