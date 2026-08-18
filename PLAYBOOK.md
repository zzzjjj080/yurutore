> ⚠️ **このファイルは履歴です。正本は `~/.claude/iOS-DEVLOG.md`（統合版 v3）。**
> 2本ぶんの知見をマージ済み。今後の追記はそちらへ。

# iPhoneアプリ開発・リリース 引き継ぎ書 v2

雀算（麻雀スコア記録）と、ゆるトレ日記（健康カレンダー）の**2本を審査提出まで**やった記録。

**新しいチャットを始めるとき、このファイル全体を最初に貼ること。**
アプリ固有の話ではなく「次も必ず使う知識」だけを書いた。

**特に「4. 実際に踏んだ罠」と「5. リリース手続き」は必ず読むこと。** 知らないと同じ時間を溶かす。

---

## 0. 新しいチャットでの切り出し方

このファイル全体を貼ったうえで、こう書けばよい。

> 前回までにiPhoneアプリを2本作って審査提出まで終えたときの引き継ぎ書です。
> これを踏まえて、今回は「〇〇」というアプリを作りたい。
> まず要件を整理してから、同じ進め方で始めてください。

---

## 1. 開発環境（このMacの現状）

| 項目 | 状態 |
|---|---|
| Mac | Apple Silicon / macOS 26 |
| Xcode | 26.6 / Swift 6.3 |
| Apple Developer Program | **登録済み**（個人・年$99） |
| **Team ID** | `A7WA598R44` |
| Apple ID（開発者） | zzzjjj080@yahoo.co.jp |
| App Store Connect の数字 | 1070981569（**Team IDとは別物**） |
| GitHub | `zzzjjj080` / SSH鍵設定済み（パスフレーズなし） |
| git identity | jin / zzzjjj080@gmail.com |
| 実機 | **iPhone Air**（iPhone18,4 / iOS 26.6）※iPhone 15から機種変更済み |
| Homebrew / gh | **入っていない** |

Claude Codeの権限は `~/.claude/settings.json` で全許可済み。許可プロンプトは出ない。

**Developer Program も実機登録も済んでいるので、3本目は2本目よりさらに速い。**

---

## 2. 進め方（この順番で2本とも成功した）

### ① HTMLで動くプロトタイプを作る

Swiftを書く前に、ブラウザで動くHTML1枚で操作感を作り込む。**これが最も効く。**

- 仕様の迷いをSwift移植前に全部潰せる
- 修正が数秒で反映される
- 画面を見ながら議論できる

ゆるトレ日記では、この段階で採点式・確定ルール・色・レイアウトを**30往復以上**調整した。
Swift移植後の手戻りはほぼゼロ。

**プロトタイプに「調整パネル」を置くと強い。** 数式のパラメータをその場で変えて結果を見られるようにすると、
仕様の議論が「どっちが良さそうか」ではなく「実際にこうなる」で進む。

### ② ロジックだけ先にSwift Packageへ（UI抜き）

`○○Core` というUI非依存のパッケージを作り、計算・判定だけ移してテストを書く。

- Xcodeを開かずに `swift test` で1秒で回せる
- 一番壊れやすい部分がテストで固定される
- UIを何度作り直してもロジックの無事を即確認できる
- 雀算45本 / ゆるトレ日記54本。リファクタが怖くなくなる

**プロトタイプで検算した内容が、そのままテストケースになる。** これが②の最大の利点。

### ③ UIを載せる

`@Observable`（iOS 17+）で状態クラスを1つ。Viewはそれを見るだけ。
`ObservableObject` + `@Published` は不要。

### ④ シミュレータで実際に触る

**「ビルドが通った」で終わらせない。必ずタップして確認する。**
2本とも、これで見つけたバグがある。

### ⑤ 実機に入れる

**触覚フィードバックは実機でしか確認できない。**
`install-device.sh` のような「接続中の端末を自動で選ぶ」スクリプトを最初に作っておくと、
機種変更しても書き換え不要で、修正のたびにすぐ入れられる。

```bash
# 接続中のiPhoneを拾う。列位置に頼るとデバイス名の空白でずれるので、UUID形式で抜く
LINE=$(xcrun devicectl list devices | grep -m1 " connected ")
DEV=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
```

---

## 3. Xcodeプロジェクトの作り方

### 前作のプロジェクトを複製するのが最速

**新規作成よりも、前のアプリの `.xcodeproj` をコピーして名前を置換するほうが速くて確実。**
ビルド設定（下記）が最初から正しく入っているため。ゆるトレ日記はこの方法で**一発でビルドが通った**。

```bash
cp -R ../Jansan/Jansan/Jansan.xcodeproj NewApp/NewApp.xcodeproj
rm -rf NewApp/NewApp.xcodeproj/xcuserdata NewApp/NewApp.xcodeproj/project.xcworkspace/xcuserdata
find NewApp -type f \( -name "*.pbxproj" -o -name "*.xcscheme" \) -print0 |
  xargs -0 sed -i '' -e 's/JansanCore/NewAppCore/g' -e 's/Jansan/NewApp/g' -e 's/雀算/新アプリ名/g'
```

**Xcode 16以降は `PBXFileSystemSynchronizedRootGroup`** なので、
`.swift` をフォルダに置くだけで自動的にビルド対象になる。pbxprojの編集は不要。

### 必ず確認するビルド設定

| 設定 | 値 | 理由 |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | **18.0** | 初期値は最新OS。そのままだと誰にも届かない |
| `TARGETED_DEVICE_FAMILY` | **1** | 初期値はiPhone+iPad+Vision。iPhone専用にするとスクショも楽 |
| `developmentRegion` | **ja**（`knownRegions` に ja） | これが en だとスワイプ削除が「Delete」のまま |
| `INFOPLIST_KEY_CFBundleDisplayName` | アプリ名 | ホーム画面の表示名 |
| `UISupportedInterfaceOrientations_iPhone` | Portrait | 縦専用なら固定 |
| `DEVELOPMENT_TEAM` | `A7WA598R44` | |

### 権限を使うなら「エンタイトルメント」も要る（重要）

**`Info.plist` の用途説明だけでは動かない。** 機能そのものの有効化が別に必要。
ゆるトレ日記はこれを忘れ、HealthKitの許可ダイアログが**一切出ない**状態で審査に出してしまった。

```xml
<!-- NewApp/NewApp.entitlements -->
<key>com.apple.developer.healthkit</key><true/>
<key>com.apple.developer.healthkit.access</key><array/>
```

```
CODE_SIGN_ENTITLEMENTS = NewApp/NewApp.entitlements;
```

確認コマンド。**これを毎回やる。**

```bash
codesign -d --entitlements - path/to/App.app | tr ',' '\n' | grep -i healthkit
```

`-allowProvisioningUpdates` を付けてビルドすれば、XcodeがApp IDの機能も自動で有効にしてくれる。

---

## 4. 実際に踏んだ罠

### 【最重要】4-1. エラーを握り潰すと、原因が永久に分からない

HealthKitの許可が失敗していたのに、`catch` で握り潰して `return false` していたため、
**ボタンを押しても無反応**になり、原因の特定に時間を要した。

```swift
// ❌ これをやると、後で必ず苦しむ
do { try await store.requestAuthorization(...) } catch { return false }

// ✅ 理由を残し、画面にも出す
private(set) var lastError: String?
do { ... } catch { lastError = error.localizedDescription; return false }
```

**無反応が一番たちが悪い。** 権限・ネットワーク・ファイルI/Oでは必ずエラーを画面に出すこと。

### 4-2. `xcode-select -p` は当てにならない

Xcodeを入れても「明示的に選択していない」状態がある。`-p` はフォールバックで正しいパスを返すのでビルドは通るが、シミュレータ連携が動かない。

```bash
ls -l /var/db/xcode_select_link   # 無ければ未選択
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # ユーザー自身が実行
```

### 4-3. シミュレータは1台だけ起動する

2台bootedだとタップが別端末に飛ぶ。`install` の前に `boot` が要る。

```bash
xcrun simctl list devices booted
xcrun simctl shutdown "iPhone 17"
```

**前作のアプリがシミュレータに残っていると干渉する。** ゆるトレ日記の確認中、
タップが雀算に飛んで混乱した。`xcrun simctl uninstall booted <前作のbundleID>` で外す。

### 4-4. シミュレータへの環境変数は `SIMCTL_CHILD_` 接頭辞

```bash
SIMCTL_CHILD_MYAPP_DEMO=1 xcrun simctl launch booted com.example.App
```

### 4-5. macOSに `timeout` コマンドは無い

GNU coreutils。終了コード127で「実行されていない」のに気づかず時間を溶かす。

### 4-6. `#if DEBUG` が効いているかは実物で確認する

```bash
xcodebuild -configuration Release ... build
strings path/to/App.app/App | grep "デモデータ"   # 何も出なければOK
find path/to/App.app -name "*.storekit"          # 何も出ないこと
```

### 4-7. 機能を足したら既存の説明文の整合性を確認する

雀算では「インターネットに接続しません」を4か所に書いていて、課金を入れて**全部が嘘になった**。
ゆるトレ日記ではHealthKitを読むので、雀算のプライバシーポリシーを**そのまま流用できなかった**。
虚偽のプライバシー表示は審査で問題になる典型。

### 4-8. SwiftUIの `Button` は中の文字色を上書きする

自前で色を決めているのにボタンの既定色（青）に染まる。`.buttonStyle(.plain)` を付ける。

### 4-9. シートの地色を指定しないとカードが見えない

シートの既定背景は白。`Color(.secondarySystemGroupedBackground)` のカードが同化して**未選択のボタンが消える**。
`.background(Color(.systemGroupedBackground))` をシートに付ける。

### 4-10. CSSでもSwiftでも「名前の衝突」は静かに壊す

- HTMLプロトタイプ：翻訳関数 `t()` がローカル変数 `const t=...` に隠されて呼べなくなった
- CSS：年表示コンテナの `.year{display:none}` が、タイトルに付けた `year` クラスにも当たって消えた

**症状が「無反応」や「消える」になるので、原因に辿り着きにくい。**

### 4-11. 個人登録だと本名が公開される

販売者名・著作権表示に本名が出る。屋号は不可。**登録前に納得しておくこと。**

### 4-12. EU配信にはトレーダーステータス（住所公開）が必要

デジタルサービス法により、氏名・住所・電話の公開が要る。
**配信地域を日本のみに限定すれば不要。** あとから広げるのは審査なしでできる。

---

## 5. リリース手続き

**順番が重要。** 飛ばすと後で詰まる。

### ① Xcodeにアカウントを追加

Xcode → Settings → Accounts → ＋ → Apple ID。証明書はアーカイブ時に自動生成される。

### ② 【重要】Explicit な App ID を先に登録する

**Xcodeの自動署名はワイルドカード（`TEAMID.*`）のApp IDを作る。**
これだと **App Store Connect のバンドルID選択肢が空**になり、アプリを登録できない。

[developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
→ ＋ → App IDs → App → **Explicit** → `com.zzzjjj080.アプリ名`

### ③ 実機を1台チームに登録する

アーカイブには開発用プロファイルが要り、その作成に実機登録が1台以上必要。
**USBで繋いでXcodeから一度実行する**のが一番早い。
デベロッパモードは**Macに繋いでXcodeが認識したあとに初めて設定に出てくる**。

### ④ App Store Connect でアプリを登録

**これをやる前にアップロードすると失敗する。**

```
Step failed: missingApp(bundleId: "com.zzzjjj080.App")
```

バンドルIDが候補に出なければ**ページをリロード**。

### ⑤ アーカイブとアップロード

```bash
xcodebuild -project App.xcodeproj -scheme App -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /tmp/App.xcarchive \
  -allowProvisioningUpdates archive
```

アーカイブがワイルドカード署名でも問題ない。**配布用の署名は書き出し時に付け直される。**

```xml
<!-- ExportOptions.plist -->
<key>method</key><string>app-store-connect</string>
<key>teamID</key><string>A7WA598R44</string>
<key>signingStyle</key><string>automatic</string>
<key>uploadSymbols</key><true/>
<key>destination</key><string>upload</string>
```

```bash
xcodebuild -exportArchive -archivePath /tmp/App.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath /tmp/export \
  -allowProvisioningUpdates
```

`destination` を `upload` にすれば、**app-specific password も APIキーも不要**。
`Upload succeeded` が出れば成功。

アップロード前に必ず確認すること。

```bash
A=/tmp/App.xcarchive/Products/Applications/App.app
/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $A/Info.plist        # ビルド番号
codesign -d --entitlements - $A | tr ',' '\n' | grep -i healthkit      # 権限
strings $A/App | grep -i "DEMO"                                        # デモデータ
```

### ⑥ 掲載情報

**スクリーンショットは、欄に表示されている寸法しか受け付けない。**

| 欄 | 必要な寸法 |
|---|---|
| iPhone 6.9インチ | 1320×2868（iPhone 17 Pro Max シミュレータがこの解像度） |
| iPhone 6.5インチ | 1242×2688 |

**現在のApp Store Connectは6.5インチ枠しか出ないことがある。** 両方作っておくのが安全。
6.9インチだけ登録すれば他サイズはApple側で自動縮小される、という話は枠が出ている場合のみ。

**iPad / Apple Watch のタブは、ビルドを添付するまで要求されてくる。** iPhone専用なら添付後に消える。

⚠️ **説明文は plain text の単独ファイルで用意すること。**
Markdownの中にコードブロックで置くと、ファイル全体をコピペする事故が起きる（実際に起きた）。

### ⑦ 「審査用に追加」を押すまでに必要なもの

**チェックリスト。1つでも欠けると押せない。**

- [ ] スクリーンショット（正しい寸法で）
- [ ] プロモーション用テキスト（170字）
- [ ] 概要（4000字）
- [ ] キーワード（100字・カンマ区切り・**スペース禁止**）
- [ ] **サポートURL**（GitHub Pages。**公開してから入れる**。404を審査で踏ませない）
- [ ] **バージョン**（`1.0`。空欄になりがち）
- [ ] **著作権**（`2026 Jin Nakamura` 形式。©は不要）
- [ ] ビルドを選択 → **ビルド行の「管理」→ 暗号化「いいえ」**（ビルドごとに聞かれる）
- [ ] **「サインインが必要です」のチェックを外す**（ログイン無しのアプリ。外さないとユーザ名/パスワードが必須になる）
- [ ] 連絡先情報（名・姓・電話・メール）
- [ ] App Reviewのメモ（後述）
- [ ] リリース方法（**手動**を推奨）
- [ ] **別ページ:** アプリのプライバシー → ポリシーURL＋「データを収集しません」
- [ ] **別ページ:** 価格および配信状況 → 無料 ＋ **日本のみ**

### ⑧ GitHub Pages

```bash
git remote add origin git@github.com:zzzjjj080/<repo>.git
git push -u origin main
```

Settings → Pages → Source: **Deploy from a branch** → Branch: **main** → フォルダ: **`/docs`**
（既定は `/ (root)` なので必ず変更する）。反映に1〜3分。

```bash
curl -s -o /dev/null -w "%{http_code}" https://zzzjjj080.github.io/<repo>/
```

---

## 6. 【新規】初回提出は Guideline 2.1 で却下されると思っておく

ゆるトレ日記は初回提出で **Guideline 2.1 - Information Needed** で却下された。
バグではなく「情報が足りない」。**新規アプリではよくある。**

Appleが求めてくる7項目。

1. **実機で撮った画面録画**（起動から主要機能まで。権限ダイアログも含める）
2. テストした端末とOSの一覧
3. アプリの機能と対象ユーザー、解決する問題
4. 主要機能への到達手順（ログイン情報があれば含む）
5. 使っている外部サービス・ツール・プラットフォーム
6. 地域による差異の有無
7. 規制産業か、第三者の保護された素材を使っているか

**対策：最初から「App Reviewに関する情報 → メモ」に全部書いておく。**
Apple自身が「今後の提出ではメモ欄に入れておくように」と書いてくる。

**書いておくべきこと（テンプレ）**

```
No account, login, or credentials are required. No in-app purchases,
no subscriptions, no user-generated content, and no network connections.

IMPORTANT FOR REVIEW: [審査環境で挙動が変わる点をここに書く]
例）the app reads step counts from HealthKit. On a review device there is
usually no step history, so every day shows 20 points. This is expected
and does not indicate a malfunction.

How to exercise the app:
1. ... （主要機能への手順を番号で）

External services: none. Only Apple frameworks (...). All data stays on the device.
Regional differences: none.
Not a medical app. No diagnosis, treatment, or health claims.
```

**審査環境で挙動が変わる点は必ず書く。** ゆるトレ日記は歩数が0になるので、
書かないと「機能していない」と誤解される。

### 返信は4000字制限

App Reviewへの返信欄は**4000字まで**。7項目を全部書くと超えるので削る必要がある。
英語で書く（App Reviewは英語で読む）。

### 却下されたら、まずビルドの中身を疑う

ゆるトレ日記は「情報不足」で却下されたが、**そのビルドには実際にHealthKitの不具合があった**。
情報だけ返信していたら、次はバグで落ちていた。

**却下は修正のチャンス。** 返信前に、指摘された箇所以外も実機で一通り触ること。
新しいビルドを上げてから返信し、**返信文に「新しいビルドを上げた」と明記する。**
順番は「ビルド差し替え → 返信 → 再提出」。返信だけでは審査は再開しない。

---

## 7. 使い回せる道具

### アプリアイコン — `Tools-MakeIcon.swift`

Swift + CoreGraphics で1024×1024を生成。デザインツール不要。

```bash
swiftc -O Tools-MakeIcon.swift -o /tmp/makeicon && /tmp/makeicon AppIcon.png
sips -Z 180 AppIcon.png --out /tmp/small.png   # 縮小して判別できるか必ず確認
```

**コツ**
- ホーム画面では60px程度まで縮む。**細い線や模様は消える**のでシルエットで見せる
- 角丸マスクで端が欠ける。**全体を86%程度に縮めて余白を確保**
- 要素は粗く。ゆるトレ日記はカレンダーを7列でなく**4×4**にした

Assetsへは `AppIcon.appiconset/Contents.json` の `platform: ios` かつ `appearances` の無い項目に `filename` を足すだけ。

### スクリーンショット — `store/MakeScreenshots.swift`

生スクショに見出しを載せて指定サイズに組む。

```bash
/tmp/makeshots store/raw store/screenshots             # 6.9インチ(1320x2868)
/tmp/makeshots store/raw store/screenshots-65 1242 2688 # 6.5インチ
```

**素材の撮り方**：`#if DEBUG` かつ環境変数でデモデータを入れ、シミュレータで撮る。

```bash
SIMCTL_CHILD_APP_DEMO=1 xcrun simctl launch booted com.zzzjjj080.App
xcrun simctl io booted screenshot store/raw/01.png
```

### 実機インストール — `install-device.sh`

接続中の端末を自動で選ぶので、機種変更しても書き換え不要。（3節参照）

---

## 8. 設計で効いたこと

### 型であり得ない状態を作れなくする

```swift
// 0を持たないので「選んでいない＝キーが無い」と一意に決まる
public enum Volume: Int { case one = 1, two = 2, three = 3 }
public var parts: [BodyPart: Volume]
```

「胸×1と胸×2が同時」が成立しなくなる。Bool複数で持つと必ず破綻する。

### 日付は `Date` ではなく専用の値型

```swift
public struct YMD: Hashable, Comparable, Codable { let year, month, day: Int }
```

カレンダーアプリが扱うのは「何月何日」であって時刻ではない。
`Date` だとタイムゾーンや夏時間で日付が前後する。**UTC固定のグレゴリオ暦で計算する。**

### 表示名ではなくIDで記録する

設定で名前を変えられるものは、**必ずidで記録して名前は表示専用にする。**
名前で記録していると、改名した瞬間に過去の記録が迷子になる。

### 過去のデータを後から書き換えない

ゆるトレ日記は「3日経つとその日の点数を確定」する。
確定後は設定を変えても動かない。**過去のカレンダーが丸ごと書き換わるのを防ぐため。**

ただし**確定日を編集したときだけ、その日を計算し直して確定し直す。**
これが無いと「忘れてた記録を足したのに点が変わらない」という別のバグになる。

### 集計の起点を持つ

ヘルスケアは何年ぶんでもデータを持っているので、起点が無いと過去が全部0%になる。
「本人が最初に入力した日」を起点にし、**ユーザーが手動で指定もできる**ようにした（機種変更対策）。

### 色は「文字が読める明度」から逆算する

カレンダーのマスの文字を黒で統一するなら、**塗りを黒文字が読める明度だけで組む。**
明度で区別できなくなるぶん、**色相の差**で分ける。
コントラスト比はコードで実測する（WCAG AA = 4.5:1）。

### 設定は種類ごとにタブを分ける

「表示」「点数」「データ」を混ぜると、**色を触るつもりで採点式を変えてしまう。**
リセットボタンもタブごとに分ける。タブ切り替えでシートの高さが変わらないよう固定する。

### 削るものを決めたら守る

ゆるトレ日記は「重さも回数も記録しない」が商品。
機能を足したくなったら、**それが核心を壊さないか**を毎回確認する。

---

## 9. Claude Codeへの依頼で効果的だった指示

- **「ビルドが通った」で終わらせず、シミュレータで実際にタップして確認させる**
- **修正したら実機にも入れさせる**（触覚は実機でしか分からない）
- 変更のたびに**小さくコミット**させる（日本語で、**なぜそうしたか**を書かせる）
- 推測で答えさせない。**バイナリを検索する・実際に起動する・curlで確認する**
- 間違えたときは**その場で認めて訂正させる**
- 仕様が技術的に矛盾するときは、**言われた通りに作らせず矛盾を指摘させる**
- **数値の仕様は「条件を先に言って、式を導出させる」**
  （ゆるトレ日記の採点式は、5つの条件を与えて一次式を導出させた）
- **検算をコードで実行させる**（目視で確認しない）

---

## 10. 2本の最終状態

### 雀算（麻雀スコア記録）

- https://github.com/zzzjjj080/jansan / https://zzzjjj080.github.io/jansan/
- `com.zzzjjj080.Jansan` / App ID 6802013584
- テスト45本 / **審査提出済み**
- 未実装: カンパ（銀行・税務情報の登録待ち）

### ゆるトレ日記（健康カレンダー）

- https://github.com/zzzjjj080/yurutore / https://zzzjjj080.github.io/yurutore/
- `com.zzzjjj080.Yurutore`
- iOS 18.0以降 / iPhone / 縦向き / 日本のみ / 無料 / 日英2言語
- **Core 54本** + アプリ層
- **審査待ち**（1.0 build 2。初回はGuideline 2.1で却下 → 修正して再提出）
- 次のアップデート分として「記録の開始日の指定」を実装済み（未提出）
- 未実装: カンパ（プロトタイプには実装済み。Swift移植は銀行・税務の完了後）

---

## 11. カンパ（App内課金）を入れる場合

**無料アプリなら銀行口座も税務情報も不要。だが課金を1つ入れると全部必要になる。**

- 有料App契約への同意
- 銀行口座の登録（**口座名義は半角ローマ字**。通帳のカナと綴りを合わせる）
- 税務情報の提出（日本＋米国向け W-8BEN）
- **Small Business Program に申請**（30% → 15%）

**アプリ完成を待たずに始められる**ので、最初に着手するのが得策。承認に時間がかかる。

課金を後回しにして先に無料でリリースする判断もできる（2本ともこの方針）。
その場合、**プライバシーポリシーが単純になる**（通信するものが無い）という副次的な利点がある。

`.storekit` はプロジェクト配下に置かない（アプリに同梱される）。
Xcodeの Edit Scheme → Run → Options から設定するのが確実。

---

## 12. 検証コマンド集

```bash
# ロジックのテスト（Xcode不要・速い）
cd Core && swift test

# シミュレータ
xcrun simctl list devices booted
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl install booted /path/App.app
SIMCTL_CHILD_APP_DEMO=1 xcrun simctl launch booted com.zzzjjj080.App
xcrun simctl terminate booted com.zzzjjj080.App   # 永続化の確認に使う
xcrun simctl io booted screenshot out.png
xcrun simctl uninstall booted com.zzzjjj080.App   # 初回起動の再現

# 実機
xcrun devicectl list devices
./install-device.sh

# アーカイブの中身
codesign -d --entitlements - App.app | tr ',' '\n' | grep -i healthkit
/usr/libexec/PlistBuddy -c "Print CFBundleVersion" App.app/Info.plist
security cms -D -i App.app/embedded.mobileprovision > p.plist
/usr/libexec/PlistBuddy -c "Print Entitlements:application-identifier" p.plist

# 公開ページ
curl -s -o /dev/null -w "%{http_code}" https://zzzjjj080.github.io/<repo>/
```

**永続化の確認は必ず `terminate` → `launch`。** 画面遷移だけでは確認にならない。
