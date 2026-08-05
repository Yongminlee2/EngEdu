package com.piyak.english.ui.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.AttributeSet
import android.view.MotionEvent
import com.piyak.english.engine.GameRound
import kotlin.math.hypot
import kotlin.random.Random

/**
 * 풍선 터뜨리기.
 * 풍선이 아래에서 위로 떠오르고, 정답 풍선을 터뜨리면 점수를 얻는다.
 * 정답 풍선이 화면 위로 도망가면 놓친 것.
 */
class BalloonGameView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : GameView(ctx, attrs) {

    private class Balloon(
        var x: Float,
        var y: Float,
        var vy: Float,
        var wobble: Float,
        val text: String,
        val color: Int,
        val correct: Boolean,
        var popped: Boolean = false,
    )

    private class Bit(var x: Float, var y: Float, var vx: Float, var vy: Float, val color: Int)

    private val rnd = Random(System.currentTimeMillis())
    private val balloons = ArrayList<Balloon>()
    private val bits = ArrayList<Bit>()

    private val colors = listOf(
        "#FF8A80", "#FFD54F", "#80CBC4", "#81D4FA", "#B39DDB", "#A5D6A7", "#FFAB91",
    ).map { Color.parseColor(it) }

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.parseColor("#8D6E63")
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.WHITE
        isFakeBoldText = true
    }

    /** 글자(이모지) → 일러스트. 있으면 풍선 안에 그림을 그린다 */
    var artResolver: ((String) -> android.graphics.drawable.Drawable?)? = null

    private var radius = 0f
    private var spawnTimer = 0f
    private var round: GameRound? = null
    private var queue = ArrayList<Pair<String, Boolean>>()  // (표시할 글자, 정답인가)

    /** 풍선이 떠오르는 속도 (난이도) */
    var riseSpeed = 1f

    fun setRound(r: GameRound) {
        round = r
        balloons.clear()
        bits.clear()
        queue = ArrayList(
            r.options.map { it to (it == r.answer) }.shuffled(rnd)
        )
        // 정답이 목록에 없으면(생성 실수) 하나 넣어 준다
        if (queue.none { it.second }) queue.add(r.answer to true)
        spawnTimer = 0f
        r.speak?.let { onSpeak?.invoke(it) }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        radius = minOf(w, h) * 0.085f
        textPaint.textSize = radius * 0.78f
        stringPaint.strokeWidth = dp(1.6f)
    }

    override fun update(dt: Float) {
        // 풍선 띄우기
        spawnTimer -= dt
        if (spawnTimer <= 0f && queue.isNotEmpty()) {
            spawnTimer = 0.55f
            val (text, correct) = queue.removeAt(0)
            balloons.add(
                Balloon(
                    x = radius * 1.3f + rnd.nextFloat() * (width - radius * 2.6f),
                    y = height + radius,
                    vy = -(height * 0.085f) * riseSpeed * (0.85f + rnd.nextFloat() * 0.3f),
                    wobble = rnd.nextFloat() * 6.28f,
                    text = text,
                    color = colors[rnd.nextInt(colors.size)],
                    correct = correct,
                )
            )
        }

        // 이동
        val it = balloons.iterator()
        var missedCorrect = false
        while (it.hasNext()) {
            val b = it.next()
            b.y += b.vy * dt
            b.wobble += dt * 2.2f
            b.x += kotlin.math.sin(b.wobble.toDouble()).toFloat() * dp(0.35f)
            if (b.y < -radius * 2.2f) {
                if (b.correct) missedCorrect = true
                it.remove()
            }
        }

        // 조각(터진 풍선)
        val bi = bits.iterator()
        while (bi.hasNext()) {
            val p = bi.next()
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vy += dp(700f) * dt
            if (p.y > height + dp(20f)) bi.remove()
        }

        // 정답 풍선을 놓쳤으면 다음 문제로
        if (missedCorrect) {
            onMiss?.invoke()
            nextRound()
        } else if (queue.isEmpty() && balloons.none { it.correct }) {
            // 정답 풍선이 사라졌는데 놓침 처리도 안 됐으면 (터뜨림) 다음 문제
            if (balloons.isEmpty()) nextRound()
        }
    }

    private fun nextRound() {
        balloons.clear()
        onNextRound?.invoke()
    }

    override fun render(canvas: Canvas) {
        for (b in balloons) {
            // 실
            val path = Path()
            path.moveTo(b.x, b.y + radius)
            path.quadTo(b.x + radius * 0.35f, b.y + radius * 1.6f, b.x, b.y + radius * 2.1f)
            canvas.drawPath(path, stringPaint)
            // 몸통
            fill.color = b.color
            canvas.drawOval(
                b.x - radius * 0.86f, b.y - radius,
                b.x + radius * 0.86f, b.y + radius, fill
            )
            // 반짝임
            fill.color = Color.parseColor("#55FFFFFF")
            canvas.drawOval(
                b.x - radius * 0.45f, b.y - radius * 0.62f,
                b.x - radius * 0.1f, b.y - radius * 0.15f, fill
            )
            // 일러스트가 있으면 그림을, 없으면 글자를 (이모지면 크게)
            val art = artResolver?.invoke(b.text)
            if (art != null) {
                val half = (radius * 0.62f).toInt()
                art.setBounds(
                    (b.x - half).toInt(), (b.y - half).toInt(),
                    (b.x + half).toInt(), (b.y + half).toInt()
                )
                art.draw(canvas)
            } else {
                val isEmoji = isEmojiText(b.text)
                textPaint.textSize = if (isEmoji) radius * 0.95f else radius * 0.78f
                // 긴 글자가 풍선 밖으로 나가지 않게
                val maxW = radius * 1.62f
                if (!isEmoji && textPaint.measureText(b.text) > maxW) {
                    textPaint.textSize *= maxW / textPaint.measureText(b.text)
                }
                textPaint.color = Color.WHITE
                canvas.drawText(b.text, b.x, b.y + textPaint.textSize * 0.35f, textPaint)
            }
        }
        for (p in bits) {
            fill.color = p.color
            canvas.drawCircle(p.x, p.y, dp(4f), fill)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked != MotionEvent.ACTION_DOWN) return true
        // 위에 그려진(뒤쪽) 풍선부터 검사
        for (i in balloons.indices.reversed()) {
            val b = balloons[i]
            if (hypot(event.x - b.x, event.y - b.y) <= radius * 1.05f) {
                pop(b)
                return true
            }
        }
        return true
    }

    private fun pop(b: Balloon) {
        balloons.remove(b)
        repeat(14) {
            val a = rnd.nextFloat() * 6.28f
            val sp = dp(120f) + rnd.nextFloat() * dp(220f)
            bits.add(
                Bit(
                    b.x, b.y,
                    kotlin.math.cos(a.toDouble()).toFloat() * sp,
                    kotlin.math.sin(a.toDouble()).toFloat() * sp,
                    b.color
                )
            )
        }
        if (b.correct) {
            onHit?.invoke()
            nextRound()
        } else {
            onMiss?.invoke()
        }
    }
}
