# 삐약영어 (Piyak English) — 설계서

2026-07-26. 개인 학습용 듀오링고 스타일 영어 앱. 판매·배포 없음, 본인 단독 사용.

## 목표

초등 기초부터 토익·토플·일상회화·여행영어까지 문제 풀이 중심으로 레벨을 통과하며 학습하는
안드로이드 앱. 듣기·말하기·읽기·쓰기·독해 전 영역. 아기자기하고 귀여운 디자인(병아리 마스코트 🐥).

## 확정 결정 사항

- **플랫폼**: 네이티브 안드로이드 (Kotlin, Views+ViewBinding, minSdk 26, WordChain과 동일 빌드 레시피)
- **트랙 4종 전부**: 기초(BASIC) · 일상회화/여행(DAILY) · 토익(TOEIC) · 토플(TOEFL)
- **레벨테스트**(배치고사)로 시작 위치 결정 + 설정에서 "자유 이동 모드"로 아무 레슨이나 선택 가능
- **말하기**: 안드로이드 SpeechRecognizer(en-US) 음성인식 자동채점 (인식 텍스트 유사도)
- **듣기**: 폰 내장 TextToSpeech(en-US). 대화문은 화자별 피치 변경으로 2인 연출
- **게임 요소**: 하트(5개) · 스트릭(달력 포함) · XP/누적레벨/배지 · 오답 복습 전부 포함
- **콘텐츠**: 처음부터 대용량(8,000+ 문제), 전부 오프라인 JSON 문제은행으로 앱에 내장

## 아키텍처

```
PiyakEnglish/
  content/            ← 원천 콘텐츠(내가 저작): vocab*.tsv, sentences*.tsv,
                         grammar.json, dialogues.json, reading.json, listening.json
  tools/gen_content.py ← 생성기: 원천 → app/src/main/assets/packs/*.json
  app/
    assets/packs/     ← basic.json, daily.json, toeic.json, toefl.json, placement.json
    java/com/piyak/english/
      model/   Question(sealed) · Lesson · Unit · Track · ContentRepo(JSON 파싱, 트랙별 lazy)
      engine/  Grader(정규화·오타허용·어순·유사도) · LessonSession(진행·하트·XP 계산)
      audio/   Tts(속도·피치·큐) · Stt(SpeechRecognizer 래퍼) · Sfx(효과음)
      db/      Db(SQLiteOpenHelper): progress/wrongs/days/badges/meta
      ui/      Main(홈) · Track(레슨 지도) · Lesson(문제 플레이어) · Placement(배치고사)
               · Review(오답복습) · Stats(배지·달력) · Settings
```

## 커리큘럼 구조

트랙 → 유닛(테마) → 레슨(문제 12개) → 문제. 레슨을 통과(하트 소진 없이 완료)하면 다음 레슨
해금. 유닛은 순차 해금. 콘텐츠 분량이 구조를 결정(생성기가 문제를 12개씩 레슨으로, 레슨 5개씩
유닛으로 패킹).

- **BASIC**: 난이도 L1~L10 (초1-2 → … → 고급). 레벨테스트 결과가 시작 유닛을 결정.
- **DAILY**: 장면 테마 유닛(인사·식당·공항·호텔·쇼핑·긴급상황 등). 말하기·듣기 비중 높음.
- **TOEIC**: 파트 유형별 유닛(사진묘사 대체형·응답·짧은대화 LC, 문법 빈칸 P5, 독해 P7).
- **TOEFL**: 학술 독해·학술 리스닝·학술 어휘 유닛.

## 문제 유형 (JSON type 필드)

| type | 설명 | 채점 |
|---|---|---|
| mcq | 4지선다(어휘 뜻, 문법 빈칸, KO→EN) | 인덱스 일치 |
| listen_mcq | TTS 듣고 4지선다 | 인덱스 일치 |
| dictation | TTS 듣고 받아쓰기 | 정규화+오타 1~2자 허용 |
| order | 한국어 문장 → 영어 단어 타일 배열 | 시퀀스 일치 |
| type_translate | 한→영 타이핑 | 정규화+대안답+오타 허용 |
| match | 단어↔뜻 5쌍 매칭 | 오터치 카운트 |
| speak | 영어 문장 소리내어 읽기 | STT 토큰 유사도 ≥0.75 (짧은 문장은 엄격) |
| listen_dialog | 2인 대화 TTS + 4지선다 (토익 LC형) | 인덱스 일치 |
| reading | 지문 + 4지선다 (토익 P7·토플형) | 인덱스 일치 |

## 채점 규칙 (Grader)

- 타이핑 정규화: 소문자화, 구두점 제거, 공백 축약, 축약형 양방향 전개(I'm↔I am 등)
- 오타 허용: 답 길이 >4면 편집거리 1, >10이면 2까지 "오타 인정" 정답 처리
- speak: 정규화 후 토큰 단위 유사도(1-WER). 4단어 이상 0.75, 3단어 이하는 1단어 오차만 허용
- 오답 시 하트 -1, 문제는 레슨 끝에 재출제(듀오링고 방식). 하트 0이면 레슨 실패
- 오답은 wrongs 테이블에 적재 → 복습 레슨(하트 미소모)으로 재출제, 2회 연속 정답 시 클리어

## 게임 시스템

- 하트 5개. 30분당 1개 자동 회복, 자정에 전체 회복. 복습 레슨 완료 시 +1
- XP: 문제 첫 시도 정답 +2, 레슨 완료 +10, 퍼펙트 +5 보너스, 배치고사 +30
- 누적 레벨: 레벨 n 도달에 필요한 누적 XP = 60·n·(n+1)/2 (레벨당 60씩 증가)
- 스트릭: 레슨 1개 이상 완료한 날 연속 카운트. 통계 화면에 월 달력 표시
- 배지 12종(첫 레슨, 7일/30일 스트릭, XP 마일스톤, 트랙별 유닛 완주, 퍼펙트 10회 등)

## 레벨테스트 (배치고사)

placement.json의 L1~L10 난이도 사다리 문제 25개. L3에서 시작, 맞으면 +1 틀리면 -1 적응형.
최근 10문항의 중앙 난이도가 배치 레벨 → BASIC 트랙 해당 레벨 유닛까지 해금 + XP 30.
앱 최초 실행 시 제안(건너뛰기 가능, 설정에서 재응시 가능).

## 디자인 (아기자기·귀여움)

- 파스텔 팔레트: 크림 배경 #FFF8E7, 병아리 옐로 #FFD54F, 코랄 #FF8A80, 민트 #80CBC4,
  하늘 #81D4FA, 라벤더 #B39DDB, 텍스트 웜브라운 #4E342E
- 병아리 마스코트 VectorDrawable (기본·기쁨·슬픔 3종) — 정답/오답 리액션
- 라운드 24dp 카드, 큰 이모지 아이콘(❤️🔥⭐🏆✈️📚🎧✍️), "삐약!" 말투 피드백 문구
- 효과음: 정답 딩동/오답 둔탁 (신스 생성 ogg, 없으면 ToneGenerator 폴백)

## 오류 처리

- STT 불가(권한 거부·오프라인 인식 실패): 말하기 문제를 "듣고 따라 말했어요" 자가 통과
  버튼으로 폴백, 채점 제외
- TTS 음성 없음: 설정 화면에서 안내 (구글 TTS 설치 유도). 듣기 문제는 텍스트 표시 폴백
- JSON 파싱은 앱 시작 시 트랙별 lazy + 실패 시 해당 트랙만 비활성

## 테스트

- JUnit: Grader 전 규칙(정규화·오타·어순·유사도), XP/레벨 공식, 하트 회복, 스트릭 계산,
  배치고사 사다리 로직
- 콘텐츠 검증 테스트: 모든 팩 JSON 파싱, 정답 인덱스 범위, 선택지 중복, 타일 재구성 가능성,
  ID 유일성
- 실기기(S20 Ultra): TTS/STT 수동 검증

## 빌드 (이 PC 고유 함정 — WordChain/WaxBall과 동일)

- `gradlew.bat :app:assembleDebug` (gradle.properties에 jbr JDK21 지정됨)
- **유닛테스트는 `GRADLE_USER_HOME=C:/gradle-home` 필수** (한글 홈경로 argfile 인코딩 문제)
- 에뮬레이터 불가 → 실기기 설치
