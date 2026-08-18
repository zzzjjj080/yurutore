#!/bin/bash
# 修正のたびに実機へ入れるためのスクリプト。
# 接続中のiPhoneを自動で選ぶので、機種変更しても書き換え不要。
set -e
cd "$(dirname "$0")/Yurutore"

# UUID形式の識別子だけを拾う（列位置に頼ると端末名の空白でずれる）
LINE=$(xcrun devicectl list devices 2>/dev/null | grep -m1 " connected ")
if [ -z "$LINE" ]; then
  echo "❌ iPhoneが接続されていません（USBで繋いで、ロックを解除してください）"
  exit 1
fi
DEV=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
MODEL=$(echo "$LINE" | sed -E 's/.*connected +//')
echo "→ ${MODEL} にインストールします"

xcodebuild -project Yurutore.xcodeproj -scheme Yurutore -configuration Debug \
  -destination "platform=iOS,id=$DEV" -derivedDataPath /tmp/yt-device \
  -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD SUCCEEDED"

xcrun devicectl device install app --device "$DEV" \
  /tmp/yt-device/Build/Products/Debug-iphoneos/Yurutore.app 2>&1 | grep -E "bundleID"
echo "✅ 完了"
