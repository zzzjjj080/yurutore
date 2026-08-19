#!/bin/bash
# 修正のたびに実機へ入れるためのスクリプト。
# 接続中のiPhoneを自動で選ぶので、機種変更しても書き換え不要。
set -e
cd "$(dirname "$0")/Yurutore"

LIST=$(xcrun devicectl list devices 2>/dev/null || true)

# grep が空振りすると set -e でここまでも来ないので、必ず || true を付ける。
# 無言で終了するのが一番たちが悪い。
pick() { echo "$LIST" | grep -m1 -E "$1" || true; }

# connected の端末だけを使う。
# available (paired) は「以前ペアリングした」だけで今は繋がっておらず、
# 選ぶとディスクイメージをマウントできずに10分待たされる。
LINE=$(pick " connected ")

if [ -z "$LINE" ]; then
  echo "❌ 繋がっているiPhoneがありません"
  echo "   USBで繋いで、ロックを解除して「信頼」を選んでください。"
  echo "   いま見えている端末:"
  echo "$LIST" | tail -n +3
  exit 1
fi

DEV=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
# 識別子より後ろが「状態＋機種」。端末名は空白を含むので列位置には頼らない。
MODEL=$(echo "$LINE" | sed -E 's/.*[0-9A-F]{12} +//' | sed -E 's/^[a-z]+( \([a-z]+\))? +//')
echo "→ ${MODEL} にインストールします"

xcodebuild -project Yurutore.xcodeproj -scheme Yurutore -configuration Debug \
  -destination "platform=iOS,id=$DEV" -destination-timeout 30 \
  -derivedDataPath /tmp/yt-device \
  -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD SUCCEEDED"

xcrun devicectl device install app --device "$DEV" \
  /tmp/yt-device/Build/Products/Debug-iphoneos/Yurutore.app 2>&1 | grep -E "bundleID"
echo "✅ 完了"
