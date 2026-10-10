#!/bin/sh
# 앱스토어용으로 보관(archive)하고 App Store Connect 에 올린다. Xcode 를 열지 않고 명령 한 줄로.
#
#   PROJECT=MyApp.xcodeproj SCHEME=MyApp TEAM=ABCDE12345 archive-upload.sh          보관 + 내보내기만
#   PROJECT=MyApp.xcodeproj SCHEME=MyApp TEAM=ABCDE12345 archive-upload.sh upload   보관 + 업로드
#
# - Xcode → Settings → Accounts 에 개발자 계정이 로그인돼 있어야 한다(소유자 몫). 없으면 "No Accounts".
# - 배포 인증서·프로파일은 -allowProvisioningUpdates 로 Xcode 가 만든다.
# - 버전·빌드 번호는 프로젝트(MARKETING_VERSION·CURRENT_PROJECT_VERSION)를 그대로 쓴다
#   (manageAppVersionAndBuildNumber=false). 안드로이드 versionName·versionCode 와 같게 둔다.
# - 같은 빌드 번호를 두 번 올리면 거절된다. 다시 올릴 때는 CURRENT_PROJECT_VERSION 을 올린다.
# - 올린 뒤 App Store Connect 에서 처리(10~30분)가 끝나야 버전 페이지에 「빌드 추가」 가 보인다.
#
# 왁뿌볼·끝말잇기 아이폰판에서 쓴 것.
set -e
: "${PROJECT:?PROJECT=<이름>.xcodeproj 를 주세요}"
: "${SCHEME:?SCHEME=<스킴> 을 주세요}"
: "${TEAM:?TEAM=<팀 ID 10자리> 를 주세요 (developer.apple.com → Membership)}"
OUT="${OUT:-$PWD/build/${SCHEME}Archive}"
mkdir -p "$OUT"
DEST=export
[ "$1" = "upload" ] && DEST=upload

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>$DEST</string>
	<key>teamID</key><string>$TEAM</string>
	<key>signingStyle</key><string>automatic</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/$SCHEME.xcarchive" \
  -derivedDataPath "$OUT/DerivedData" -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$OUT/$SCHEME.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT/export" -allowProvisioningUpdates
echo "끝: $OUT ($DEST)"
