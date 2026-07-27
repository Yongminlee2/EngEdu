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
    }

    /** 4지선다. passage 가 있으면 독해(지문) 문제. */
    data class Mcq(
        override val id: String,
        val prompt: String,
        val choices: List<String>,
        val answer: Int,
        val passage: String? = null,
        override val explain: String? = null,
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
                    o.getInt("answer"), o.optString("passage").ifEmpty { null }, explain
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

        private fun strList(a: JSONArray): List<String> = (0 until a.length()).map { a.getString(it) }
        private fun strListOpt(a: JSONArray?): List<String> =
            if (a == null) emptyList() else (0 until a.length()).map { a.getString(it) }
    }
}
