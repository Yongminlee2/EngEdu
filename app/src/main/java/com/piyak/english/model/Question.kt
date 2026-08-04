package com.piyak.english.model

import org.json.JSONArray
import org.json.JSONObject

/** 문제 한 개. 팩 JSON 의 type 필드로 구분한다. */
sealed class Question {
    abstract val id: String
    abstract val explain: String?

    /** 팩 JSON 의 skill 값(있으면 우선). 문법 문제처럼 유형만으로 구분 못 하는 경우에 쓴다. */
    var skillTag: String? = null

    /** 실력 영역: vocab / listening / speaking / writing / grammar / reading */
    val skill: String get() = skillTag ?: defaultSkill()

    private fun defaultSkill(): String = when (this) {
        is Mcq -> if (passage != null) "reading" else "vocab"
        is ListenMcq, is ListenDialog -> "listening"
        is Dictation -> "listening"
        is Order, is TypeTranslate -> "writing"
        is Speak -> "speaking"
        is Match -> "vocab"
        is Math -> "m_calc"
    }

    /** 4지선다. passage 가 있으면 독해(지문) 문제. */
    data class Mcq(
        override val id: String,
        val prompt: String,
        val choices: List<String>,
        val answer: Int,
        val passage: String? = null,
        override val explain: String? = null,
        /** 문제 위에 크게 띄울 그림 이모지 (초등영어 그림 문제) */
        val bigEmoji: String? = null,
        /**
         * 보기를 **그림으로** 보여줄 때의 drawable 이름들 (choices 와 같은 순서).
         *
         * 뜻을 한국어 낱말로 물으면 그 문제는 한국어 화자 전용이 된다.
         * 그림으로 물으면 **어느 나라 아이도 그대로 풀 수 있고**,
         * 그림·소리·철자가 한 화면에 붙는 편이 학습에도 낫다.
         * 비어 있으면 예전처럼 글자 보기를 쓴다.
         */
        val choiceArt: List<String> = emptyList(),
        /**
         * 문제 위에 크게 띄울 **그림 이름**.
         *
         * 뜻을 한국어로 적는 대신 그림을 보여 주고 영어를 묻는 문제에 쓴다.
         * 문제문에 한국어 낱말이 없으므로 문장만 번역하면 어느 언어에서도 그대로 쓸 수 있다.
         */
        val bigArt: String? = null,
    ) : Question()

    /** TTS 로 tts 를 들려준 뒤 4지선다. */
    data class ListenMcq(
        override val id: String,
        val tts: String,
        val prompt: String,
        val choices: List<String>,
        val answer: Int,
        override val explain: String? = null,
    ) : Question()

    /** TTS 를 듣고 받아쓰기. */
    data class Dictation(
        override val id: String,
        val tts: String,
        val answer: String,
        val alts: List<String> = emptyList(),
        val hintKo: String? = null,
        override val explain: String? = null,
    ) : Question()

    /** 한국어 문장을 보고 영어 단어 타일을 순서대로 배열. */
    data class Order(
        override val id: String,
        val ko: String,
        val en: String,
        val extras: List<String> = emptyList(),
        override val explain: String? = null,
    ) : Question() {
        val tokens: List<String> get() = en.split(" ").filter { it.isNotBlank() }
    }

    /** 한국어 문장을 영어로 타이핑. */
    data class TypeTranslate(
        override val id: String,
        val ko: String,
        val answer: String,
        val alts: List<String> = emptyList(),
        override val explain: String? = null,
    ) : Question()

    /** 단어↔뜻 5쌍 매칭. */
    data class Match(
        override val id: String,
        val pairs: List<Pair<String, String>>,
        override val explain: String? = null,
    ) : Question()

    /** 영어 문장을 소리 내어 읽기(STT 채점). */
    data class Speak(
        override val id: String,
        val en: String,
        val ko: String? = null,
        override val explain: String? = null,
    ) : Question()

    /**
     * 수학 문제. 그림(visual)과 입력 방식(input)을 조합해 모든 수학 유형을 표현한다.
     * input = number(숫자 키패드) / choice(4지선다) / text(식·문자 답)
     */
    data class Math(
        override val id: String,
        val prompt: String,
        val visual: MathVisual? = null,
        val input: String = "number",
        val answer: String = "",
        val alts: List<String> = emptyList(),
        val choices: List<String> = emptyList(),
        val answerIndex: Int = -1,
        val unit: String = "",
        override val explain: String? = null,
    ) : Question()

    /** 2인 대화를 듣고 4지선다 (토익 LC 스타일). */
    data class ListenDialog(
        override val id: String,
        val lines: List<Pair<String, String>>, // (화자 A/B, 대사)
        val prompt: String,
        val choices: List<String>,
        val answer: Int,
        override val explain: String? = null,
    ) : Question()

    companion object {
        fun fromJson(o: JSONObject): Question =
            build(o).apply { skillTag = o.optString("skill").ifEmpty { null } }

        private fun build(o: JSONObject): Question {
            val id = o.getString("id")
            val explain = o.optString("explain").ifEmpty { null }
            return when (val t = o.getString("type")) {
                "mcq", "reading" -> Mcq(
                    id, o.getString("prompt"), strList(o.getJSONArray("choices")),
                    o.getInt("answer"), o.optString("passage").ifEmpty { null }, explain,
                    o.optString("bigEmoji").ifEmpty { null },
                    strListOpt(o.optJSONArray("choiceArt")),
                    o.optString("bigArt").ifEmpty { null }
                )
                "listen_mcq" -> ListenMcq(
                    id, o.getString("tts"), o.optString("prompt", "무엇을 들었나요?"),
                    strList(o.getJSONArray("choices")), o.getInt("answer"), explain
                )
                "dictation" -> Dictation(
                    id, o.getString("tts"), o.getString("answer"),
                    strListOpt(o.optJSONArray("alts")), o.optString("hintKo").ifEmpty { null }, explain
                )
                "order" -> Order(
                    id, o.getString("ko"), o.getString("en"),
                    strListOpt(o.optJSONArray("extras")), explain
                )
                "type_translate" -> TypeTranslate(
                    id, o.getString("ko"), o.getString("answer"),
                    strListOpt(o.optJSONArray("alts")), explain
                )
                "match" -> {
                    val arr = o.getJSONArray("pairs")
                    val pairs = (0 until arr.length()).map {
                        val p = arr.getJSONArray(it)
                        p.getString(0) to p.getString(1)
                    }
                    Match(id, pairs, explain)
                }
                "speak" -> Speak(id, o.getString("en"), o.optString("ko").ifEmpty { null }, explain)
                "math" -> {
                    val choices = strListOpt(o.optJSONArray("choices"))
                    Math(
                        id = id,
                        prompt = o.getString("prompt"),
                        visual = MathVisual.fromJson(o.optJSONObject("visual")),
                        input = o.optString("input", if (choices.isEmpty()) "number" else "choice"),
                        answer = o.optString("answer"),
                        alts = strListOpt(o.optJSONArray("alts")),
                        choices = choices,
                        answerIndex = o.optInt("answerIndex", -1),
                        unit = o.optString("unit"),
                        explain = explain,
                    )
                }
                "listen_dialog" -> {
                    val arr = o.getJSONArray("lines")
                    val lines = (0 until arr.length()).map {
                        val p = arr.getJSONArray(it)
                        p.getString(0) to p.getString(1)
                    }
                    ListenDialog(
                        id, lines, o.getString("prompt"),
                        strList(o.getJSONArray("choices")), o.getInt("answer"), explain
                    )
                }
                else -> throw IllegalArgumentException("unknown question type: $t")
            }
        }

        /**
         * 문제문을 **폰 언어로** 조립한다.
         *
         * 팩에는 한국어 원문(prompt)과 함께 뼈대 키(tk)·값(ta)이 실려 있다.
         * 한국 폰이거나 번역이 없으면 **한국어 원문을 그대로** 돌려준다.
         */
        private fun tpl(o: JSONObject, fallback: String? = null): String {
            val ko = fallback ?: o.getString("prompt")
            return com.piyak.english.i18n.Tpl.sentence(
                o.optString("tk").ifEmpty { null }, strListOpt(o.optJSONArray("ta")), ko
            )
        }

        private fun strList(a: JSONArray): List<String> = (0 until a.length()).map { a.getString(it) }
        private fun strListOpt(a: JSONArray?): List<String> =
            if (a == null) emptyList() else (0 until a.length()).map { a.getString(it) }
    }
}
