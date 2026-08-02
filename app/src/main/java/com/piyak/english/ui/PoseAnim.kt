package com.piyak.english.ui

import android.content.Context
import android.graphics.drawable.AnimationDrawable
import android.graphics.drawable.Drawable
import android.widget.ImageView

/**
 * 포즈 그림에 두 번째 프레임(`이름_b`)이 있으면 둘을 번갈아 보여주는
 * 드로어블을 만든다 — 라이브러리 없이 움짤처럼 움직이는 병아리 (발주서 #06·#07).
 *
 * 프레임이 없는 그림은 그냥 정지 그림으로 들어가므로, 아무 데나 안심하고 쓸 수 있다.
 */
object PoseAnim {

    /** 프레임 교대 간격 — 포즈마다 어울리는 리듬이 다르다 (원본 ms, _b ms) */
    private fun timing(name: String): Pair<Int, Int> = when (name) {
        "ck_idle" -> 2600 to 200      // 가끔 눈 깜빡
        "ck_cheer" -> 330 to 330      // 신나는 날갯짓
        "ck_listen" -> 950 to 950     // 고개 까딱까딱
        "ck_write" -> 650 to 650      // 사각사각
        "ck_speak" -> 380 to 380      // 재잘재잘
        "ck_sleep" -> 1300 to 1300    // 새근새근
        else -> 800 to 800
    }

    /** 두 프레임 애니메이션 드로어블 (또 없으면 null) */
    fun of(ctx: Context, resId: Int): Drawable? {
        if (resId == 0) return null
        val name = try {
            ctx.resources.getResourceEntryName(resId)
        } catch (e: Exception) {
            return null
        }
        val bId = ctx.resources.getIdentifier(name + "_b", "drawable", ctx.packageName)
        if (bId == 0) return null
        val f1 = ctx.getDrawable(resId) ?: return null
        val f2 = ctx.getDrawable(bId) ?: return null
        val (d1, d2) = timing(name)
        return AnimationDrawable().apply {
            isOneShot = false
            addFrame(f1, d1)
            addFrame(f2, d2)
        }
    }

    /** 이미지뷰에 넣는다 — 두 번째 프레임이 있으면 움직이고, 없으면 정지 그림 */
    fun applyTo(img: ImageView, resId: Int) {
        if (resId == 0) return
        val anim = of(img.context, resId)
        if (anim != null) {
            img.setImageDrawable(anim)
            img.post { (img.drawable as? AnimationDrawable)?.start() }
        } else {
            img.setImageResource(resId)
        }
    }
}
