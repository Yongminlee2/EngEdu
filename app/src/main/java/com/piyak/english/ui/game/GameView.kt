package com.piyak.english.ui.game

import android.content.Context
import android.graphics.Canvas
import android.util.AttributeSet
import android.view.View

/**
 * 미니게임 공통 뼈대.
 * onDraw 안에서 시간 간격(dt)을 계산해 update → render 를 돌리고,
 * 게임이 진행 중이면 다음 프레임을 스스로 예약한다.
 */
abstract class GameView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    /** 정답을 맞혔을 때 (점수 증가) */
    var onHit: (() -> Unit)? = null

    /** 틀렸거나 놓쳤을 때 */
    var onMiss: (() -> Unit)? = null

    /** 한 라운드가 끝나 다음 문제가 필요할 때 */
    var onNextRound: (() -> Unit)? = null

    /** 게임 전체가 끝났을 때 */
    var onFinish: (() -> Unit)? = null

    /** 읽어 줄 말이 생겼을 때 */
    var onSpeak: ((String) -> Unit)? = null

    protected var running = false
        private set

    private var lastFrameNs = 0L

    fun startLoop() {
        if (running) return
        running = true
        lastFrameNs = 0L
        postInvalidateOnAnimation()
    }

    fun stopLoop() {
        running = false
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val now = System.nanoTime()
        val dt = if (lastFrameNs == 0L) 0f else ((now - lastFrameNs) / 1_000_000_000f).coerceAtMost(0.05f)
        lastFrameNs = now

        if (running) update(dt)
        render(canvas)
        if (running) postInvalidateOnAnimation()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopLoop()
    }

    /** dt(초)만큼 상태를 진행시킨다 */
    protected abstract fun update(dt: Float)

    /** 현재 상태를 그린다 */
    protected abstract fun render(canvas: Canvas)

    protected fun dp(v: Float): Float = v * resources.displayMetrics.density
}

/**
 * 이 글자가 그림문자(이모지)인가.
 *
 * ⚠ 예전에는 `text[0].code > 0x2000` 으로 봤는데 **한글(U+AC00~)·한자·가나가 전부
 * 걸려서** 한글 보기가 이모지 크기(훨씬 큼)로 그려지고 폭에 맞춰 줄이는 처리도
 * 건너뛰었다. 영어 옆에 한글이 유독 크게 나오던 원인.
 */
internal fun isEmojiText(s: String): Boolean {
    if (s.isEmpty()) return false
    val cp = s.codePointAt(0)
    return cp >= 0x1F000 ||           // 🍎 🐥 … 그림문자 평면
        cp in 0x2190..0x21FF ||       // 화살표
        cp in 0x2600..0x27BF ||       // ⭐ ✏️ ✔ 기타 기호
        cp in 0x2B00..0x2BFF          // ⬅ ⭕ 등
}
