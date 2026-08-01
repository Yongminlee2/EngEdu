# Design QA — 삐약영어

## 최종 디자인 구성

- 메인 화면은 사용자 피드백에 따라 작업 전 구조로 복원했다.
- `MainActivity.kt`와 `activity_main.xml`은 저장소 기준 버전과 동일하다.
- 레슨, 정오답 피드백, 여정, 설정, 통계, 지갑 등 나머지 화면의 새 디자인은 유지했다.
- 실제 기기 캡처: `C:/Users/사용자/.codex/visualizations/2026/08/01/019fbcdb-6db2-76e2-942e-fbb5c77b1a54/english-restored-home-phone.png`

## 실기 검증

- 기기: Samsung SM-G988N
- 기존 학습 데이터가 유지되는 업데이트 설치를 사용했다.
- 학습 현황, 실력 지표, 레벨테스트, 학습 코스 카드가 이전 메인 구조로 표시된다.
- 앱 실행 후 `MainActivity`가 최상위 화면인 것을 확인했다.
- 새로 디자인한 다른 화면의 소스는 변경하지 않았다.

## 자동 검증

- `testDebugUnitTest`: 74 tests, 0 failures, 0 errors
- `assembleDebug`: 성공
- `lintDebug`: 성공, 0 errors
- 휴대폰 업데이트 설치: 성공

final result: passed
