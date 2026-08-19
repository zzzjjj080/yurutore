#!/bin/bash
# 修正のたびに実機へ入れるためのスクリプト。
# 繋がっているiPhoneを自動で選ぶので、機種変更しても書き換え不要。
set -e
cd "$(dirname "$0")/Yurutore"

# macOSに timeout コマンドは無いので perl で代用する
run() { perl -e 'alarm shift; exec @ARGV' "$@"; }

LIST=$(xcrun devicectl list devices 2>/dev/null || true)

# grep が空振りすると set -e でその場で死ぬ。無言の終了が一番たちが悪いので必ず || true
grab() { echo "$LIST" | grep -E "$1" || true; }

# USB接続を先に、次にペアリング済み（Wi-Fi経由）を候補にする。
# available は繋がっていないこともあるので、実際に応答するかを確かめてから使う。
CANDIDATES=$(printf '%s\n%s\n' "$(grab ' connected ')" "$(grab ' available ')" | grep -v '^$' || true)

DEV=""
while read -r LINE; do
  [ -z "$LINE" ] && continue
  ID=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
  [ -z "$ID" ] && continue
  if run 45 xcrun devicectl device info details --device "$ID" >/dev/null 2>&1; then
    DEV="$ID"
    # 識別子より後ろが「状態＋機種」。端末名は空白を含むので列位置には頼らない。
    MODEL=$(echo "$LINE" | sed -E 's/.*[0-9A-F]{12} +//' | sed -E 's/^[a-z]+( \([a-z]+\))? +//')
    break
  fi
  echo "…応答なし: $(echo "$LINE" | sed -E 's/ +/ /g' | cut -c1-40)"
done <<< "$CANDIDATES"

if [ -z "$DEV" ]; then
  echo "❌ 使えるiPhoneがありません"
  echo "   USBで繋ぐか、Macと同じWi-Fiに繋いでロックを解除してください。"
  echo "   いま見えている端末:"
  echo "$LIST" | tail -n +3
  exit 1
fi

echo "→ ${MODEL} にインストールします"

xcodebuild -project Yurutore.xcodeproj -scheme Yurutore -configuration Debug \
  -destination "platform=iOS,id=$DEV" -destination-timeout 60 \
  -derivedDataPath /tmp/yt-device \
  -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD SUCCEEDED"

xcrun devicectl device install app --device "$DEV" \
  /tmp/yt-device/Build/Products/Debug-iphoneos/Yurutore.app 2>&1 | grep -E "bundleID"
echo "✅ 完了"
