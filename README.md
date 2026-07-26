# 삐약영어 🐥

혼자 쓰는 듀오링고 스타일 영어 학습 앱. 초등 1학년 수준부터 토익·토플·일상회화·여행영어까지
문제를 풀며 레슨·유닛을 통과해 올라가는 방식. 완전 오프라인 문제은행 내장(말하기 채점만 인터넷 권장).

## 주요 기능

- **4개 트랙**: 기초 차근차근(10단계) · 일상/여행 영어 · 토익 · 토플 — 총 **8,206문제** 내장
- **문제 유형 9종**: 4지선다, 듣고 고르기(TTS), 받아쓰기, 단어 타일 어순 배열, 한→영 영작,
  단어-뜻 매칭, 말하기(음성인식 자동채점), 2인 대화 듣기(토익 LC형), 지문 독해
- **레벨테스트**: 25문항 적응형 배치고사 → 내 레벨(초1~토플)에 맞는 유닛까지 자동 해금
- **게임 요소**: 하트 5개(30분당 1개 회복) · 스트릭(달력) · XP/레벨 · 배지 12종 · 오답 복습(하트 보상)
- 폰 내장 TTS(영어 원어민 음성, 속도 조절)와 구글 음성인식 사용 — 별도 서버·계정 불필요

## 빌드

```
gradlew.bat :app:assembleDebug          # APK 빌드
gradlew.bat :app:testDebugUnitTest      # 단위테스트 (GRADLE_USER_HOME=C:/gradle-home 필요)
```

- JDK: gradle.properties 에 Android Studio jbr(JDK21) 지정됨
- 산출물: `app/build/outputs/apk/debug/app-debug.apk` (약 6.9MB)
- 실기기 설치: `adb install -r 삐약영어-v1.0.apk` (에뮬레이터는 이 PC에서 불가)

## 콘텐츠 파이프라인

```
content/                     ← 원천 데이터 (직접 편집)
  vocab_L1..L10.tsv            레벨별 어휘 1,170단어 (단어/품사/뜻/예문/예문해석)
  sentences.tsv                문장 355개 (기초·여행 문장)
  grammar.jsonl                문법 4지선다 250문항 (레벨 태그)
  dialogues.json               일상·여행 대화 27장면 (9테마)
  toeic.json                   토익 P5 60 · P7 지문 12 · LC 대화 12
  toefl.json                   토플 학술독해 8지문 · 강의 6 · 학술어휘 24
tools/gen.js                 ← 생성기: node tools/gen.js
app/src/main/assets/packs/   ← 생성 결과 (basic/daily/toeic/toefl/placement.json)
```

**문제 추가 방법**: content/ 파일에 단어·문장·문법을 추가하고 `node tools/gen.js` 실행 후 재빌드.
어휘 한 단어를 추가하면 뜻고르기·영어로쓰기·듣기·받아쓰기·예문 문제가 자동으로 4~5개 생성된다.

## 구조

```
model/    Question(sealed, 9유형) · ContentRepo(팩 JSON lazy 로더)
engine/   Grader(정규화·오타허용·어순·말하기 유사도) · LessonSession(하트·재출제·XP)
          Economy(레벨·하트회복·스트릭) · Badges · Placement(적응형 사다리)
audio/    Tts(속도·2인 피치) · Stt(SpeechRecognizer) · Sfx(합성 효과음 4종)
db/       SQLite: progress/wrongs/days/badges/meta
ui/       Main(홈) · Track(레슨 지도) · Lesson(문제 플레이어+복습) · Placement · Stats · Settings
```

## 채점 규칙 요약

- 타이핑: 소문자·구두점·축약형(I'm↔I am) 정규화 후 비교, 5자 이상은 오타 1자(11자+는 2자) 인정
- 말하기: 인식 문장과 토큰 유사도 — 4단어 이상 75%, 3단어는 1오차, 1~2단어는 정확히.
  음성인식 2회 실패 시 건너뛰기 버튼 표시(하트 차감 없음)
- 오답: 하트 -1, 레슨 끝에 재출제, 오답노트 적재 → 복습에서 2연속 정답 시 클리어

## 테스트

JUnit 25건: Grader 규칙 · LessonSession 진행/하트/XP · Economy 레벨·하트·스트릭 ·
Placement 사다리/중앙값 · 콘텐츠 팩 전수 검증(파싱·정답범위·중복·타일 재구성).
