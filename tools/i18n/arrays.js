/**
 * 순서가 있는 문자열 묶음 (string-array).
 *
 * 요일처럼 **개수와 순서가 정해진** 것은 낱개 문자열보다 배열이 안전하다.
 * 언어마다 개수가 다르면 gen_strings.js 가 막는다.
 */
module.exports = {

  // 달력 머리글. 일요일 시작 — StatsActivity 의 calGrid 가 그 순서로 칸을 채운다
  weekday_short: {
    ko: ["일", "월", "화", "수", "목", "금", "토"],
    en: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
    ja: ["日", "月", "火", "水", "木", "金", "土"],
    zh: ["日", "一", "二", "三", "四", "五", "六"],
    es: ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"],
    fr: ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"],
    de: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"],
    pt: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"],
    ru: ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"],
    vi: ["CN", "T2", "T3", "T4", "T5", "T6", "T7"],
    th: ["อา", "จ", "อ", "พ", "พฤ", "ศ", "ส"],
    in: ["Min", "Sen", "Sel", "Rab", "Kam", "Jum", "Sab"],
  },
};
