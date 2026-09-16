#!/bin/bash
# 修正のたびに実機へ入れるためのスクリプト。
# 使える端末を自動で選ぶので、機種変更しても書き換え不要。
#
#   ./install-device.sh            前回うまくいった端末を優先して入れる
#   ./install-device.sh <UUID>     端末を指定して入れる
set -eo pipefail   # grep に繋いでいてもビルドの失敗を見落とさない（引き継ぎ書 4-145）
cd "$(dirname "$0")"
REMEMBER="$(pwd)/.last-device"

# どのビルドが入ったかを画面で確かめられるようにする（引き継ぎ書 4-145）。
# 手で増やす方式だと増やし忘れて印が嘘をつくので、ここで毎回作る。
STAMP="b$(git rev-list --count HEAD)$(git diff --quiet HEAD -- . || echo +) $(date '+%m/%d %H:%M')"

cd Yurutore

LIST=$(xcrun devicectl list devices 2>/dev/null || true)

# grep が空振りすると set -e でその場で死ぬ。無言の終了が一番たちが悪いので必ず || true
grab() { echo "$LIST" | grep -E "$1" || true; }
ids()  { grab "$1" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true; }
name() { grab "$1" | sed -E 's/.*[0-9A-F]{12} +//' | sed -E 's/^[a-z]+( \([a-z]+\))? +//'; }

# 前回の端末 → USB接続 → ペアリング済み（Wi-Fi）の順に試す。
# 応答するかどうかだけでは足りない。ネットワーク上に見えていても
# developer disk image をマウントできない端末があり、それは実際に
# ビルドさせてみないと分からない。
CANDIDATES=$(printf '%s\n%s\n%s\n' \
  "${1:-$(cat "$REMEMBER" 2>/dev/null || true)}" "$(ids ' connected ')" "$(ids ' available ')" \
  | grep -v '^$' | awk '!seen[$0]++' || true)

if [ -z "$CANDIDATES" ]; then
  echo "❌ 使えるiPhoneがありません"
  echo "   USBで繋ぐか、Macと同じWi-Fiに繋いでロックを解除してください。"
  echo "$LIST" | tail -n +3
  exit 1
fi

for DEV in $CANDIDATES; do
  MODEL=$(name "$DEV")
  echo "→ ${MODEL:-$DEV} を試します"
  # 30秒で見切りをつける。ここを長くすると、駄目な端末1台で10分待たされる。
  if xcodebuild -project Yurutore.xcodeproj -scheme Yurutore -configuration Debug \
      -destination "platform=iOS,id=$DEV" -destination-timeout 30 \
      -derivedDataPath /tmp/yt-device YT_BUILD_STAMP="$STAMP" \
      -allowProvisioningUpdates build 2>&1 | grep -qE "BUILD SUCCEEDED"; then
    xcrun devicectl device install app --device "$DEV" \
      /tmp/yt-device/Build/Products/Debug-iphoneos/Yurutore.app 2>&1 | grep -E "bundleID"
    echo "$DEV" > "$REMEMBER"      # 次回はこれを最初に試す
    # 入ったと決めつけず、入れた .app の中身を読んで言う
    A=/tmp/yt-device/Build/Products/Debug-iphoneos/Yurutore.app
    IN=$(/usr/libexec/PlistBuddy -c "Print YTBuildStamp" "$A/Info.plist" 2>/dev/null || echo "")
    echo "✅ ${MODEL:-$DEV} に入れました"
    echo "   設定画面のいちばん下に「$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$A/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$A/Info.plist")) · $IN」が出ていれば入れ替わっています"
    exit 0
  fi
  echo "   …使えませんでした。次を試します"
done

echo "❌ どの端末にも入れられませんでした"
echo "$LIST" | tail -n +3
exit 1
