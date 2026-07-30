# 삐약영어 + 삐약수학 분리 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 한 앱(삐약공부)을 삐약영어(기존 저장소·데이터 유지)와 삐약수학(새 로컬 저장소·새 출발) 두 앱으로 분리한다.

**Architecture:** MainActivity 는 이미 `subject` 파라미터로 두 과목을 겸하므로, 각 앱에서 런처를 MainActivity 로 바꾸고 과목을 고정한다. 콘텐츠 팩·생성기·과목 전용 화면을 각자 들어내고, 남는 쪽 테스트를 조정한다.

**Tech Stack:** Kotlin/Views, SQLite, Node 생성기, JUnit. 설계서: `docs/superpowers/specs/2026-07-31-split-into-two-apps-design.md`

## Global Constraints

- 삐약영어의 `applicationId` 는 **`com.piyak.english` 절대 유지** (바꾸면 250원·알파벳·진행도 소실)
- 삐약영어 설치는 반드시 `adb install -r` (제거 후 설치 금지 — 데이터 소실)
- 삐약수학의 `applicationId` 는 `com.piyak.math`, **소스 패키지(namespace)는 `com.piyak.english` 그대로** (폴더 이동 없음 — applicationId 만 바꾸면 데이터가 분리된다)
- 빌드·테스트는 항상 `$env:GRADLE_USER_HOME='C:/gradle-home'` 로 (한글 홈 경로 함정)
- 팩을 지우거나 재생성하면 **반드시 `node tools/gen_index.js`** 실행
- 삐약수학은 원격이 생길 때까지 **로컬 git 에만 커밋** (push 없음)
- 모든 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- 사용자 데이터(DB 행)는 어떤 작업에서도 삭제하지 않는다

---

## Phase 1 — 삐약영어 (기존 저장소 `C:\workAndroid\PiyakEnglish`)

### Task 1: 이름 "삐약영어" + 런처를 영어 홈으로 고정

**Files:**
- Modify: `app/src/main/res/values/strings.xml` (app_name)
- Modify: `app/src/main/AndroidManifest.xml` (런처 이동, SubjectActivity 등록 삭제)
- Modify: `app/src/main/java/com/piyak/english/ui/MainActivity.kt` (과목 고정)
- Delete: `app/src/main/java/com/piyak/english/ui/SubjectActivity.kt`, `app/src/main/res/layout/activity_subject.xml`

**Interfaces:**
- Produces: 런처 = MainActivity, `subject` 는 항상 `Subject.ENGLISH`. Task 3·4 는 이 전제로 수학 분기를 지운다.

- [ ] **Step 1: app_name 변경** — `<string name="app_name">삐약공부</string>` → `삐약영어`
- [ ] **Step 2: 매니페스트** — SubjectActivity 의 `<activity>` 블록(LAUNCHER intent-filter 포함)을 삭제하고, MainActivity 의 `<activity>` 에 그 intent-filter 를 옮긴다. `android:exported="true"` 로.
- [ ] **Step 3: MainActivity 과목 고정**

```kotlin
// 변경 전: subject = Subject.of(intent.getStringExtra("subject") ?: db.meta("subject_last", "english"))
// 변경 후 (영어 전용 앱):
subject = com.piyak.english.model.Subject.ENGLISH
```

과목 전환 버튼(`btnSwitchSubject`)은 `visibility = GONE` (finish() 하면 앱이 꺼져 버린다).
- [ ] **Step 4: SubjectActivity.kt + activity_subject.xml 삭제**, 컴파일 확인:
  `./gradlew.bat assembleDebug` → BUILD SUCCESSFUL
- [ ] **Step 5: Commit** — `chore: 삐약영어 리브랜딩 — 런처를 영어 홈으로 고정, 과목 대문 제거`

### Task 2: 수학 콘텐츠·생성기 제거

**Files:**
- Delete: `app/src/main/assets/packs/math_*.json` (math_k~math_h3 13개 + math_placement.json)
- Delete: `tools/math/` (lib.js, elementary.js, middle.js, high.js, word.js), `tools/gen_math.js`
- Modify: `tools/gen_index.js` (수학 트랙 참조가 있으면 제거 — 팩 디렉터리 스캔 방식이면 수정 불요)
- Regenerate: `app/src/main/assets/packs/index.json`

- [ ] **Step 1: math 팩 14개 삭제** — `Remove-Item app/src/main/assets/packs/math_*.json`
- [ ] **Step 2: tools/math 와 gen_math.js 삭제**
- [ ] **Step 3: `node tools/gen_index.js`** 실행 → index.json 에 영어 트랙만 남는지 확인 (트랙 11개: elem, basic, daily, toeic, toefl, listening, speaking, writing, grammar, reading, placement)
- [ ] **Step 4: Commit** — `chore: 수학 콘텐츠·생성기 제거 (삐약수학으로 이관)`

### Task 3: LessonActivity 수학 분기 + 수학 전용 뷰 제거

**Files:**
- Modify: `app/src/main/java/com/piyak/english/ui/LessonActivity.kt`
- Delete: `ui/MathVisualView.kt`, `ui/NumberPadView.kt`, `ui/GroupDragView.kt`, `ui/BalanceScaleView.kt`, `ui/BarBuildView.kt`, `ui/ScratchPadView.kt`
- Delete: `engine/MathGrader.kt`
- Modify: `app/src/main/res/layout/activity_lesson.xml`, `view_q_math.xml` 삭제
- 유지: `model/Question.kt` 의 `Question.Math`, `model/MathVisual.kt`, `model/Subject.kt` 의 MATH·MathGrades (MainActivity·Stats·Placement 가 참조 — 컴파일 파급을 막는다. 팩이 없으므로 실행엔 안 나타남)

**Interfaces:**
- Consumes: Task 1 (subject 항상 ENGLISH → 수학 경로 도달 불가)
- Produces: LessonActivity 는 영어 문제 타입만 처리. `is Question.Math ->` 분기는 `{}` (도달 불가) 로 남긴다.

- [ ] **Step 1: LessonActivity 에서 삭제** — `showMath`, `showClockSet`, `showGroupDrag`, `showFractionPaint`, `showShapeSort`, `showNumberLineDrag`, `showAngleSet`, `showBalance`, `showBarBuild`, `showGather`, `useBubbleForNumber`, `trimNum`, `speakKorean`, `setUpScratchPad`/`showScratch`/`resetScratchPad` 및 관련 임포트. `is Question.Math ->` 분기는 빈 블록으로.
- [ ] **Step 2: 뷰 6개 + MathGrader.kt + view_q_math.xml 삭제**, activity_lesson.xml 의 연습장(scratchPad·scratchBar·btnScratch) 요소 삭제
- [ ] **Step 3: 빌드** — `./gradlew.bat assembleDebug` → BUILD SUCCESSFUL (남은 참조가 있으면 컴파일러가 알려 준다 — 따라가며 정리)
- [ ] **Step 4: Commit** — `refactor: 수학 전용 화면·채점기 제거 (LessonActivity -500줄)`

### Task 4: 테스트 정리 + 전체 통과

**Files:**
- Delete: `app/src/test/java/com/piyak/english/MathTest.kt`
- Modify: `InteractionTest.kt` (수학 팩 순회·visualInput·저학년 버블 테스트 삭제, 영어 버블·widthScore·선잇기·소리 테스트 유지)
- Modify: `PlacementSubjectTest.kt`, `ContentPackTest.kt` (수학 트랙 참조 제거)
- 유지: DbMigrationTest, LetterStrokeTest, LettersTest, GraderTest, EconomyTest, WalletTest, LessonSessionTest, SkillsTest, MiniGamesTest

- [ ] **Step 1: 위 삭제·수정 수행**
- [ ] **Step 2: `./gradlew.bat testDebugUnitTest`** → 전부 통과 (실패하면 남은 수학 참조를 지운다)
- [ ] **Step 3: Commit** — `test: 수학 테스트 제거, 영어 전용으로 조정`

### Task 5: v3.0 빌드·설치·데이터 확인 + README

**Files:**
- Modify: `app/build.gradle.kts` (versionCode 19, versionName "3.0")
- Modify: `README.md` (v3.0 절: 분리 이유·삐약수학 저장소 안내)

- [ ] **Step 1: 버전 올리고 빌드** — `삐약영어-v3.0.apk` 로 복사 (기존 `삐약공부-*.apk` 삭제)
- [ ] **Step 2: 설치** — `adb install -r` (연결 안 돼 있으면 APK 준비만 하고 표시)
- [ ] **Step 3: 데이터 유지 검증** — 설치 후:
  `adb shell run-as com.piyak.english cat databases/piyak.db > /tmp/en.db` 후 coins 값 확인 (250 이상), letters 행 존재 확인. 앱 이름이 "삐약영어"로 뜨는지.
- [ ] **Step 4: README + Commit + Push** — `v3.0: 삐약영어로 분리 (수학은 PiyakMath 저장소로)`

---

## Phase 2 — 삐약수학 (새 저장소 `C:\workAndroid\PiyakMath`)

### Task 6: 저장소 복제 + 정체성 (패키지·이름·아이콘)

**Files:**
- Create: `C:\workAndroid\PiyakMath\` (전체 복사본, `.git`·`build`·`.gradle`·`*.apk` 제외)
- Modify: `app/build.gradle.kts` — `applicationId = "com.piyak.math"`, versionCode 1, versionName "1.0" (namespace 는 그대로!)
- Modify: `app/src/main/res/values/strings.xml` — app_name "삐약수학"
- Modify: `app/src/main/res/values/colors.xml` + `mipmap-anydpi-v26/ic_launcher.xml`·`ic_launcher_round.xml` — 아이콘 배경을 분홍으로

- [ ] **Step 1: 복사** — `robocopy C:\workAndroid\PiyakEnglish C:\workAndroid\PiyakMath /E /XD .git build .gradle .idea /XF *.apk` (robocopy 는 1~7 도 성공 코드)
- [ ] **Step 2: `git init` + 첫 커밋** — `init: 삐약공부에서 분기 (원본 EngEdu@<해시>)`
- [ ] **Step 3: applicationId·버전·이름 수정**
- [ ] **Step 4: 아이콘 배경색** — colors.xml 에 `<color name="launcher_bg">#F7C6C7</color>` 추가, ic_launcher.xml 두 파일의 `<background android:drawable="@color/cream"/>` → `@color/launcher_bg`
- [ ] **Step 5: 빌드 확인 + Commit** — `chore: 삐약수학 정체성 (com.piyak.math · 분홍 아이콘 · v1.0)`

### Task 7: 런처를 수학 홈으로 고정

Task 1 과 동일 수순, 과목만 반대:

- [ ] **Step 1: 매니페스트** — SubjectActivity 블록 삭제, MainActivity 에 LAUNCHER + exported
- [ ] **Step 2: MainActivity** — `subject = Subject.MATH` 고정, `btnSwitchSubject` GONE, SubjectActivity.kt·activity_subject.xml 삭제
- [ ] **Step 3: 빌드 확인 + Commit** — `chore: 런처를 수학 홈으로 고정`

### Task 8: 영어 콘텐츠·생성기 제거

- [ ] **Step 1: 영어 팩 삭제** — packs/ 에서 `elem, basic, daily, toeic, toefl, listening, speaking, writing, grammar, reading, placement`.json (math_placement.json 은 유지!)
- [ ] **Step 2: 영어 생성기 삭제** — `tools/gen.js`, `tools/gen_elem_english.js` (gen_math.js·gen_index.js·tools/math 유지)
- [ ] **Step 3: `node tools/gen_index.js`** → index.json 에 수학 14트랙만
- [ ] **Step 4: Commit** — `chore: 영어 콘텐츠·생성기 제거`

### Task 9: 영어 기능 제거 (알파벳·말하기·놀이터·영어 분기)

**Files:**
- Delete: `ui/AlphabetActivity.kt`, `ui/TraceActivity.kt`, `ui/TraceView.kt`, `engine/Letters.kt`, `engine/Grader.kt`, 관련 레이아웃(activity_alphabet, activity_trace)
- Delete: `ui/PlaygroundActivity.kt`, `ui/GameActivity.kt`, `ui/game/BalloonGameView.kt`, `ui/game/BasketGameView.kt`, `ui/game/GameView.kt`, `ui/game/LineMatchView.kt`(영어 선잇기), 관련 레이아웃(activity_playground, activity_game) 및 영어 문제 레이아웃(view_q_mcq, view_q_match, view_q_order, view_q_speak, view_q_type)
- 유지: `ui/game/BubbleChoiceView.kt` (수학 버블이 씀), `engine/MiniGames.kt` (`wrongNumbers` 를 수학 버블이 씀), `ScratchPadView`(연습장), Tts(한국어 읽기)
- Modify: `LessonActivity.kt` — 영어 분기 삭제: `showMcq`·듣기(ListenMcq/ListenDialog)·`showSpeak`(SpeechRecognizer)·`showWrite`·`showMatch`·`showReading` 및 영어 TTS 경로. `is Question.Math ->` 만 남긴다 (영어 타입 분기는 빈 블록)
- Modify: `MainActivity.kt` — 알파벳·놀이터 진입 카드 제거 (MATH 에선 원래 GONE 이지만 참조 코드 정리)
- Modify: 매니페스트 — 삭제한 액티비티 등록 제거

- [ ] **Step 1: 위 삭제·수정 수행, 컴파일러 오류 따라가며 정리**
- [ ] **Step 2: 빌드** → BUILD SUCCESSFUL
- [ ] **Step 3: Commit** — `refactor: 영어 기능 제거 (알파벳·말하기·놀이터·영어 문제 분기)`

### Task 10: 테스트 정리 + 전체 통과

- [ ] **Step 1: 삭제** — GraderTest, LettersTest, LetterStrokeTest, MiniGamesTest(게임 보상 부분; `wrongNumbers` 검사는 MathTest 로 이동), InteractionTest 의 영어 부분(버블 fits 영어 문장·선잇기), ContentPackTest·PlacementSubjectTest 의 영어 부분
- [ ] **Step 2: 유지 확인** — MathTest, DbMigrationTest, EconomyTest, WalletTest, LessonSessionTest, SkillsTest, InteractionTest 수학 부분(visualInput·저학년 버블·조작형 검사)
- [ ] **Step 3: `./gradlew.bat testDebugUnitTest`** → 전부 통과
- [ ] **Step 4: Commit** — `test: 영어 테스트 제거, 수학 전용으로 조정`

### Task 11: v1.0 빌드·설치·동작 확인 + 새 README

- [ ] **Step 1: README.md 새로 작성** — 삐약수학 소개·빌드법(GRADLE_USER_HOME 함정 포함)·분리 이력은 삐약영어 저장소 링크로. 날짜(년월일)는 적지 않는다
- [ ] **Step 2: 빌드** → `삐약수학-v1.0.apk`
- [ ] **Step 3: 설치** (`adb install` — 새 패키지라 -r 불요) 후 확인: 앱 이름·분홍 아이콘, 수학 홈 바로 진입, 레벨테스트 동작, 레슨 1개 풀어 코인 적립(0원→적립), 크래시 기록기 파일 없음
- [ ] **Step 4: 로컬 Commit** — `v1.0: 삐약수학 첫 판 (수학 14트랙 13,205문제)` — **push 하지 않는다** (원격 미정)

### Task 12: 마무리 — 두 앱 공존 확인 + 메모리 갱신

- [ ] **Step 1: 폰에서 확인** — 홈 화면에 삐약영어·삐약수학 아이콘이 나란히, 서로 다른 배경색
- [ ] **Step 2: 프로젝트 메모리(piyak-english-project.md) 갱신** — 두 저장소 체제·공용 버그는 두 번 고침·삐약수학 원격 미연결 상태를 기록
- [ ] **Step 3: 삐약영어 README 에도 분리 완료 기록 후 커밋·푸시**

## 검증 요약 (설계서 D 절 대응)

| 검증 | 어디서 |
|---|---|
| 영어 단위테스트 통과 | Task 4 |
| 수학 단위테스트 통과 | Task 10 |
| 250원·알파벳·진행도 유지 | Task 5 Step 3 |
| 수학 새 출발 동작 (레벨테스트→레슨→코인) | Task 11 Step 3 |
| 아이콘 2개 구분 | Task 12 Step 1 |
