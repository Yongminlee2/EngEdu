package com.piyak.english.i18n

import android.content.Context
import android.content.res.Resources

/**
 * 문제 팩의 번역 키를 **폰 언어의 문장으로 조립한다.**
 *
 * 팩에는 한국어 원문과 함께 `tk`(뼈대 키) + `ta`(끼워 넣을 값)가 실려 있다.
 *
 *   tk = "e8755f8c",  ta = ["다섯", "5", "🍎🍎🍎🍎🍎"]
 *   tpl_e8755f8c(ko) = "하나씩 세어 보면 %1$s, 모두 %2$s개예요. %3$s"
 *   tpl_e8755f8c(en) = "Count one by one: %1$s. That's %2$s in all. %3$s"
 *
 * 이렇게 하면 **문제 팩을 언어마다 복제하지 않아도** 12개 언어가 나온다.
 * 번역이 없는 뼈대는 한국어 원문을 그대로 쓴다 — 화면이 비는 일은 없다.
 *
 * 한국어 폰에서는 아무 일도 하지 않는다(원문이 곧 정답이라 비용 0).
 */
object Tpl {

    private var res: Resources? = null
    private var pkg: String = ""
    private var passthrough = true

    /** "tpl_<키>" → 리소스 id. 0 은 "번역 없음"으로 캐시된다 */
    private val ids = HashMap<String, Int>()

    /** 인자·선택지 안에 박혀 오는 한국어 낱말 (사과·쿠키·삼각형 …) */
    private var words: Map<String, String> = emptyMap()

    /** 답 옆에 붙는 단위 (개·명·분·원 …) */
    private var units: Map<String, String> = emptyMap()

    private val HANGUL = Regex("[가-힣]+")

    fun init(ctx: Context) {
        val c = ctx.applicationContext
        val r = c.resources
        val lang = r.configuration.locales.get(0).language
        res = r
        pkg = c.packageName
        passthrough = lang == "ko"
        if (passthrough) return

        words = dict(r, "tpl_words")
        units = dict(r, "tpl_units")
    }

    /** "한국어|번역" 한 줄씩 담긴 string-array 를 표로 읽는다 */
    private fun dict(r: Resources, name: String): Map<String, String> = try {
        r.getStringArray(r.getIdentifier(name, "array", pkg))
            .mapNotNull {
                val i = it.indexOf('|')
                if (i <= 0) null else it.substring(0, i) to it.substring(i + 1)
            }.toMap()
    } catch (e: Exception) {
        emptyMap()
    }

    private fun idOf(name: String): Int {
        ids[name]?.let { return it }
        val id = try { res?.getIdentifier(name, "string", pkg) ?: 0 } catch (e: Exception) { 0 }
        ids[name] = id
        return id
    }

    /**
     * 뼈대 + 값 → 폰 언어의 문장.
     * 번역이 없거나 서식이 안 맞으면 **한국어 원문을 그대로** 돌려준다.
     */
    fun sentence(tk: String?, ta: List<String>, ko: String): String {
        if (passthrough || tk.isNullOrEmpty()) return ko
        val id = idOf("tpl_$tk")
        if (id == 0) return ko
        return try {
            val args: Array<Any> = Array(ta.size) { word(ta[it]) }
            res!!.getString(id, *args)
        } catch (e: Exception) {
            ko                       // 인자 개수가 어긋나도 문제는 계속 풀려야 한다
        }
    }

    /**
     * 문자열 안의 한국어 낱말만 갈아 끼운다 (그림 라벨·선택지·단위에 쓴다).
     * 사전에 없는 낱말은 그대로 둔다 — 반쪽이라도 읽히는 편이 낫다.
     */
    fun word(s: String): String {
        if (passthrough || words.isEmpty() || s.isEmpty()) return s
        if (!hasHangul(s)) return s
        // 통째로 등록된 구절이 먼저다.
        // "일의 자리를 뺄 수 없으니 십의 자리에서 10을 빌려와요." 같은 문장은
        // 낱말로 쪼개 바꾸면 말이 안 되므로 문장째 갈아 끼운다.
        words[s]?.let { return it }
        // 앞뒤 공백은 문장을 이어 붙이는 데 쓰이므로 살려 둔다
        // (XML 은 리소스 값의 앞뒤 공백을 지워 버려서, 사전에는 공백 없이 넣는다)
        val t = s.trim()
        if (t.length != s.length) words[t]?.let { return s.replace(t, it) }
        // 여러 줄이면 줄마다 따로 찾는다 (도형 안내문처럼 문장이 줄단위로 붙는 경우)
        if (s.contains('\n')) return s.split('\n').joinToString("\n") { word(it) }
        return HANGUL.replace(s) { m -> words[m.value] ?: m.value }
    }

    /**
     * 단위(개·명·분·원 …). 낱말 사전과 따로 두는 이유는 겹치는 글자 때문이다.
     * 그림 라벨의 "원"은 **동그라미**지만 단위의 "원"은 **돈**이다.
     */
    fun unit(s: String): String {
        if (passthrough || s.isEmpty()) return s
        return units[s] ?: word(s)
    }

    fun words(list: List<String>): List<String> =
        if (passthrough) list else list.map { word(it) }

    private fun hasHangul(s: String): Boolean {
        for (c in s) if (c in '가'..'힣') return true
        return false
    }
}
