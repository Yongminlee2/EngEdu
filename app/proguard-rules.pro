# 삐약영어 릴리스 축소 규칙
#
# 이 앱은 반사(reflection)를 거의 쓰지 않는다. 콘텐츠 JSON 도 org.json 으로 손수 읽으므로
# 모델 클래스 이름이 바뀌어도 상관없다. 그래서 기본 규칙만으로 충분하다.
#
# 다만 **리소스를 이름으로 찾는 곳**이 있다 (Resources.getIdentifier):
#   - 단어 그림 word_*, 병아리 ck_*, 단계 카드 stage_* 등
# 이건 코드가 아니라 리소스 축소기의 문제라서 res/raw/keep.xml 이 막는다.
# 여기(코드 축소기)에서는 getIdentifier 자체가 지워지지 않게만 두면 된다.

# 크래시 기록을 읽을 수 있게 줄번호를 남긴다 (설정 → 🐞 마지막 오류 기록)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
