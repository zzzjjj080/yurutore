import Foundation
import YurutoreCore

/// 画面に出る文字はここに集める。
/// 端末の言語ではなくアプリ内の設定で切り替えるので、String Catalog ではなく自前で持つ。
enum L {
    static func t(_ ja: String, _ en: String, _ lang: AppLanguage) -> String {
        lang == .en ? en : ja
    }

    static func weekdayShort(_ w: Int, _ lang: AppLanguage) -> String {
        lang == .en ? ["S","M","T","W","T","F","S"][w] : ["日","月","火","水","木","金","土"][w]
    }

    static let monthsEN = ["January","February","March","April","May","June",
                           "July","August","September","October","November","December"]

    static func monthTitle(_ y: Int, _ m: Int, _ lang: AppLanguage) -> String {
        lang == .en ? "\(monthsEN[m-1]) \(y)" : "\(y)年\(m)月"
    }
    static func yearTitle(_ y: Int, _ lang: AppLanguage) -> String {
        lang == .en ? "\(y)" : "\(y)年"
    }
    static func monthShort(_ m: Int, _ lang: AppLanguage) -> String {
        lang == .en ? String(monthsEN[m-1].prefix(3)) : "\(m)月"
    }
    static func dayTitle(_ d: YMD, _ lang: AppLanguage) -> String {
        let w = weekdayShort(d.weekday, lang)
        return lang == .en ? "\(monthShort(d.month, lang)) \(d.day) (\(w))"
                           : "\(d.month)月\(d.day)日（\(w)）"
    }

    static func partName(_ p: BodyPart, _ lang: AppLanguage) -> String {
        lang == .en ? p.english : p.japanese
    }
    static func unitName(_ u: ActivityUnit, _ lang: AppLanguage) -> String {
        lang == .en ? u.english : u.japanese
    }

    // ホーム
    static func statPass(_ l: AppLanguage) -> String  { t("達成した日", "Days passed", l) }
    static func statSteps(_ l: AppLanguage) -> String { t("平均歩数", "Avg steps", l) }
    static func statScore(_ l: AppLanguage) -> String { t("平均点", "Avg score", l) }
    static func detailBtn(_ l: AppLanguage) -> String { t("詳細を見る", "See details", l) }
    static func today(_ l: AppLanguage) -> String     { t("今日", "Today", l) }
    static func pts(_ l: AppLanguage) -> String       { t("点", "pts", l) }
    static func close(_ l: AppLanguage) -> String     { t("閉じる", "Close", l) }
    static func done(_ l: AppLanguage) -> String      { t("完了", "Done", l) }
    static func cancel(_ l: AppLanguage) -> String    { t("キャンセル", "Cancel", l) }
    static func yes(_ l: AppLanguage) -> String       { t("はい", "Yes", l) }

    // 入力
    static func steps(_ l: AppLanguage) -> String     { t("歩数", "Steps", l) }
    static func bodyParts(_ l: AppLanguage) -> String { t("動かした部位", "Body parts", l) }
    static func restDay(_ l: AppLanguage) -> String   { t("休養日", "Rest day", l) }
    static func notLogged(_ l: AppLanguage) -> String { t("まだ未入力", "Not logged yet", l) }
    static func tapToPick(_ l: AppLanguage) -> String { t("タップで選ぶ", "Tap to set", l) }
    static func manual(_ l: AppLanguage) -> String    { t("手入力", "Manual", l) }
    static func auto(_ l: AppLanguage) -> String      { t("自動", "Auto", l) }
    static func settled(_ l: AppLanguage) -> String   { t("確定済み", "Locked", l) }
    static func syncing(_ n: Int, _ l: AppLanguage) -> String {
        t("同期中 · あと\(n)日で確定", "Syncing · locks in \(n)d", l)
    }
    static func breakdown(_ s: Int, _ e: Int, _ l: AppLanguage) -> String {
        t("歩数 \(s)点 ＋ 運動 \(e)点　合格は\(Scorer.passLine)点から",
          "Steps \(s) + exercise \(e)　pass is \(Scorer.passLine)+", l)
    }
    static func ifAuto(_ n: Int, _ l: AppLanguage) -> String {
        t("記録どおりなら \(n)点", "By the record it would be \(n)", l)
    }

    // 詳細
    static func detailTitle(_ y: Int, _ m: Int, _ l: AppLanguage) -> String {
        t("\(y)年\(m)月の詳細", "\(monthsEN[m-1]) \(y)", l)
    }
    static func otherEx(_ l: AppLanguage) -> String  { t("その他の運動", "Other exercise", l) }
    static func total(_ l: AppLanguage) -> String    { t("合計", "Total", l) }
    static func perDay(_ l: AppLanguage) -> String   { t("1日あたり", "Per day", l) }
    static func noneYet(_ l: AppLanguage) -> String  { t("今月はまだありません", "Nothing yet this month", l) }
    static func since(_ d: YMD, _ l: AppLanguage) -> String {
        t("\(d.year)年\(d.month)月\(d.day)日から集計しています（初めて運動を記録した日）",
          "Counting from \(monthShort(d.month, l)) \(d.day), \(d.year) — the first day you logged exercise", l)
    }
    static func sinceNone(_ l: AppLanguage) -> String {
        t("まだ運動の記録がありません", "No exercise logged yet", l)
    }

    // 年
    static func ySumPass(_ l: AppLanguage) -> String   { t("達成した日", "Days passed", l) }
    static func ySumLogged(_ l: AppLanguage) -> String { t("記録した日", "Days logged", l) }
    static func chartTitle(_ l: AppLanguage) -> String { t("月ごとの達成率（%）", "Pass rate by month (%)", l) }

    // 設定
    static func settings(_ l: AppLanguage) -> String   { t("設定", "Settings", l) }
    static func tabDisplay(_ l: AppLanguage) -> String { t("表示", "Display", l) }
    static func tabScore(_ l: AppLanguage) -> String   { t("点数", "Scoring", l) }
    static func tabData(_ l: AppLanguage) -> String    { t("データ", "Data", l) }
    static func language(_ l: AppLanguage) -> String   { t("言語", "Language", l) }
    static func theme(_ l: AppLanguage) -> String      { t("配色", "Appearance", l) }
    static func light(_ l: AppLanguage) -> String      { t("ライト", "Light", l) }
    static func dark(_ l: AppLanguage) -> String       { t("ダーク", "Dark", l) }
    static func system(_ l: AppLanguage) -> String     { t("端末に合わせる", "Match device", l) }
    static func weekStart(_ l: AppLanguage) -> String  { t("週の始まり", "Week starts", l) }
    static func monday(_ l: AppLanguage) -> String     { t("月曜", "Monday", l) }
    static func sunday(_ l: AppLanguage) -> String     { t("日曜", "Sunday", l) }
    static func calColors(_ l: AppLanguage) -> String  { t("カレンダーの色", "Calendar colors", l) }
    static func colorHint(_ l: AppLanguage) -> String {
        t("色は4段階です。点数の濃淡ではなく、歩数と運動のどちらの合格ラインを越えたかで決まります。",
          "Four colors, not a gradient. The color says which of the two lines you crossed.", l)
    }
    /// 4段階の呼び名。設定のサンプルと、はじめの説明で使う。
    static func tierName(_ tier: DayTier, _ l: AppLanguage) -> String {
        switch tier {
        case .none:    t("どちらも未達成", "Neither", l)
        case .half:    t("片方だけ達成", "One of two", l)
        case .both:    t("両方達成", "Both", l)
        case .perfect: t("100点", "100 points", l)
        }
    }
    static func palettePick(_ l: AppLanguage) -> String { t("配色を選ぶ", "Pick a palette", l) }
    static func reminder(_ l: AppLanguage) -> String   { t("リマインダー", "Reminder", l) }
    static func reminderHint(_ l: AppLanguage) -> String {
        t("その日まだ運動を記録していないときだけ、そっと知らせます。記録済みの日や休養日には鳴りません。毎日せかされるのは「ゆる」ではないので、既定ではオフにしてあります。",
          "A quiet nudge, only on days you have not logged any exercise yet. Nothing on days you already logged, or rest days. Being nagged every night is not very relaxed, so this is off by default.", l)
    }
    static func reminderTime(_ l: AppLanguage) -> String { t("知らせる時刻", "Time", l) }
    // MARK: - 合格ラインの設定

    static func lineTitle(_ l: AppLanguage) -> String {
        t("\(Scorer.passLine)点のラインを決める", "Set the \(Scorer.passLine)-point line", l)
    }
    static func lineHint(_ l: AppLanguage) -> String {
        t("歩数と運動に、それぞれ「合格ライン」と「目標ライン」を決めます。\n合格ラインで\(Scorer.passPoints)点、目標ラインで\(Scorer.goalPoints)点。\n両方が合格ラインに届いた日が\(Scorer.passLine)点＝合格です。\n片方だけでは合格になりません。歩くことと体を動かすこと、両方を続けるためです。",
          "Set a pass line and a goal line, for steps and for exercise.\nThe pass line is worth \(Scorer.passPoints) points, the goal line \(Scorer.goalPoints).\nA day that reaches both pass lines scores \(Scorer.passLine) — a pass.\nOne of them alone is not enough: the point is to keep doing both.", l)
    }
    static func stepsGroup(_ l: AppLanguage) -> String { t("歩数", "Steps", l) }
    static func exGroup(_ l: AppLanguage) -> String    { t("運動の数", "Exercises", l) }
    static func passLineLabel(_ l: AppLanguage) -> String {
        t("合格ライン（\(Scorer.passPoints)点）", "Pass line (\(Scorer.passPoints))", l)
    }
    static func goalLineLabel(_ l: AppLanguage) -> String {
        t("目標ライン（\(Scorer.goalPoints)点）", "Goal line (\(Scorer.goalPoints))", l)
    }
    static func exCount(_ n: Int, _ l: AppLanguage) -> String {
        t("\(n)種目", n == 1 ? "1 exercise" : "\(n) exercises", l)
    }
    static func lineSummary(steps: Int, ex: Int, _ l: AppLanguage) -> String {
        t("\(steps.formatted())歩 ＋ \(ex)種目 ＝ \(Scorer.passLine)点（合格）",
          "\(steps.formatted()) steps + \(exCount(ex, l)) = \(Scorer.passLine) (pass)", l)
    }
    static func perExercise(_ points: Int, _ l: AppLanguage) -> String {
        t("運動1種目につき約\(points)点", "About \(points) points per exercise", l)
    }
    static func recalcTitle(_ l: AppLanguage) -> String {
        t("過去の点数", "Past scores", l)
    }
    static func recalcHint(_ l: AppLanguage) -> String {
        t("確定した日（\(Journal.graceDays)日より前）の点数は、設定を変えても動きません。見返すたびに過去が変わっては困るからです。\n過去も新しい設定で付け直したいときだけ、下のボタンを押してください。",
          "Days already settled (older than \(Journal.graceDays) days) keep their score when you change these settings, so your history does not shift under you.\nUse the button below only if you want past days recalculated too.", l)
    }
    static func recalcBtn(_ l: AppLanguage) -> String {
        t("過去の点数も計算し直す", "Recalculate past scores", l)
    }
    static func recalcConfirmTitle(_ l: AppLanguage) -> String {
        t("過去の点数を計算し直しますか？", "Recalculate past scores?", l)
    }
    static func recalcConfirmBody(_ n: Int, _ l: AppLanguage) -> String {
        n == 0
        ? t("いまの設定では、確定済みの日の点数は変わりません。",
            "With the current settings, no settled day would change.", l)
        : t("確定済みのうち\(n)日ぶんの点数が、いまの設定で変わります。元には戻せません。\n手入力した点数と記録そのものは変わりません。",
            "\(n) settled day(s) will change to match the current settings. This cannot be undone.\nManually entered scores and your records are not affected.", l)
    }
    static func startLabel(_ l: AppLanguage) -> String { t("記録の開始日", "Start date", l) }
    static func startAuto(_ l: AppLanguage) -> String { t("自動", "Automatic", l) }
    static func startManual(_ l: AppLanguage) -> String { t("指定する", "Choose", l) }
    static func startHint(_ l: AppLanguage) -> String {
        t("この日から記録を始めた、という日です。それより前の日は濃いグレーになり、点数も達成率にも入りません。\n「自動」にすると、初めて運動を記録した日から数えます。機種変更でヘルスケアに古い歩数が残っている場合は、ここで指定してください。",
          "The day you started keeping this diary. Days before it turn dark grey and are excluded from scores and the pass rate.\n\"Automatic\" counts from the first day you logged exercise. If old step data carried over from a previous phone, set the date here.", l)
    }
    static func startCurrent(_ d: YMD, _ l: AppLanguage) -> String {
        t("\(d.year)年\(d.month)月\(d.day)日から集計します",
          "Counting from \(monthShort(d.month, l)) \(d.day), \(d.year)", l)
    }
    static func actHint(_ l: AppLanguage) -> String {
        t("筋トレ1種目（3セット×10回）と同じくらいになる量を入れる。\n例：ラジオ体操なら5分、自転車なら5分。\n走り回る運動は歩数にも入るので、そのぶん多めの量にする（球技が30分なのはこのため）。",
          "Enter the amount that feels like one strength exercise (3 sets of 10).\nFor example 5 minutes of calisthenics, or 5 minutes of cycling.\nRunning-based exercise also shows up in your step count, so set a larger amount.", l)
    }
    static func addAct(_ l: AppLanguage) -> String    { t("運動を追加", "Add exercise", l) }
    static func matrixTitle(_ l: AppLanguage) -> String { t("いまの設定での点数", "Scores with current settings", l) }
    static func matrixHint(_ l: AppLanguage) -> String {
        t("縦＝歩数（1000歩ごと）、横＝運動の数。上の設定を変えると、その場で書き換わる。色が濃いマスが合格（\(Scorer.passLine)点以上）。\n合格ラインと目標ラインの行には印を付けてあります。",
          "Rows are steps (every 1,000), columns are exercises. Darker cells are a pass (\(Scorer.passLine)+).\nThe pass line and goal line rows are marked.", l)
    }
    static func resetDefaults(_ l: AppLanguage) -> String { t("デフォルトに戻す", "Reset to defaults", l) }
    static func aboutBtn(_ l: AppLanguage) -> String  { t("はじめの説明を見る", "Read the intro again", l) }

    // データ
    static func dataTitle(_ l: AppLanguage) -> String { t("記録の書き出し・読み込み", "Export & import", l) }
    static func dataHint(_ l: AppLanguage) -> String {
        t("書き出したファイルは表計算ソフトでそのまま開けます。機種変更のときや、念のための控えに使ってください。読み込むと、同じ日の記録は上書きされます。",
          "The exported file opens directly in a spreadsheet. Use it when you change phones, or as a backup. Importing overwrites records for the same dates.", l)
    }
    static func exportBtn(_ l: AppLanguage) -> String { t("書き出す（CSV）", "Export (CSV)", l) }
    static func importBtn(_ l: AppLanguage) -> String { t("読み込む（CSV）", "Import (CSV)", l) }
    static func dataCount(_ n: Int, _ l: AppLanguage) -> String {
        t("いま\(n)日ぶんの記録があります", "\(n) days recorded", l)
    }

    // ヘルスケア
    static func hkBanner(_ l: AppLanguage) -> String { t("歩数が取れていません", "Steps are not coming in", l) }
    static func hkBannerSub(_ l: AppLanguage) -> String {
        t("ヘルスケアへのアクセスを許可すると、歩数が自動で入ります。",
          "Allow access to Health and your steps fill in automatically.", l)
    }
    static func hkAllow(_ l: AppLanguage) -> String { t("許可する", "Allow", l) }

    // 初回の説明
    struct Page { let title: String; let body: String }
    static func onboarding(_ l: AppLanguage) -> [Page] {
        l == .en ? [
            .init(title: "Staying healthy, loosely",
                  body: "I wanted to move my body a reasonable amount. But apps that make you log weights and reps wore me out in about three days.\n\nWhat I wanted was something I could fill in within five seconds, and take in a whole month at a glance. It did not exist, so I made it for myself."),
            .init(title: "Only two things to enter",
                  body: "Steps come in automatically from Health.\nAll you tap is which body parts you worked and other exercise. Each tap cycles ×1 → ×2 → ×3.\n\nNo weights, no reps, not even duration."),
            .init(title: "80 is a pass",
                  body: "Steps and exercise are each worth 40 points when they reach their pass line, so a day that reaches both scores 80 and passes. The calendar colour changes, and at the end of the month you can see how many days you managed.\n\nWalking alone is not a pass, and neither is exercise alone. The point is to keep doing both."),
            .init(title: "Set your pass line",
                  body: "The same target cannot suit someone who walks 5,000 steps and someone who walks 15,000. So decide yours now.\n\nIf you are not sure, leave it as it is. Everything here can be changed later in settings.")
        ] : [
            .init(title: "健康を、ざっくり続けるために",
                  body: "ある程度は体を動かしたい。でも重さも回数も記録するアプリは、正直3日で嫌になりました。\n\nほしかったのは、5秒で入れられて、1か月を一目で見渡せるもの。なかったので自分用に作りました。"),
            .init(title: "入れるのは2つだけ",
                  body: "歩数はヘルスケアから勝手に入ります。\nあなたが押すのは動かした部位とその他の運動だけ。押すたびに ×1 → ×2 → ×3 と増えます。\n\n重さも回数も、時間すら入れません。"),
            .init(title: "80点が合格",
                  body: "歩数と運動には、それぞれ「合格ライン」があります。どちらも届くと40点＋40点で80点、その日は合格です。カレンダーの色が変わるので、月末に「今月は何日できたか」が一目で分かります。\n\n歩いただけ、運動しただけでは合格になりません。両方をぼちぼち続けるためです。"),
            .init(title: "合格ラインを決めましょう",
                  body: "普段5000歩の人と15000歩の人で、同じ基準はおかしいからです。ここで自分の線を決めてください。\n\n迷ったらそのままで大丈夫です。あとから設定でいくらでも変えられます。")
        ]
    }
    static func obNext(_ l: AppLanguage) -> String  { t("次へ", "Next", l) }
    static func obStart(_ l: AppLanguage) -> String { t("この設定ではじめる", "Start with this", l) }
    static func obSkip(_ l: AppLanguage) -> String  { t("とばす", "Skip", l) }
    static func obWalk(_ l: AppLanguage) -> String  { t("1日にこれくらい歩きたい", "Steps I want each day", l) }
    static func obMove(_ l: AppLanguage) -> String  { t("1日にこれくらい運動したい", "Exercise I want each day", l) }
    static func obLater(_ l: AppLanguage) -> String {
        t("目標ライン（\(Scorer.goalPoints)点）や運動の種類は、設定であとから決められます。",
          "Goal lines (\(Scorer.goalPoints) points) and the exercise list can be set later.", l)
    }

    // 投げ銭（コーヒーを奢る）
    static func tipHeader(_ l: AppLanguage) -> String { t("このアプリが気に入ったら", "If you like this app", l) }
    static func tipBuy(_ l: AppLanguage) -> String    { t("開発者にコーヒーを奢る", "Buy the developer a coffee", l) }
    static func tipThanks(_ l: AppLanguage) -> String { t("ありがとうございます", "Thank you", l) }
    static func tipClose(_ l: AppLanguage) -> String  { t("閉じる", "Close", l) }
    static func tipNone(_ l: AppLanguage) -> String   { t("いまは受け付けられません", "Not available right now", l) }
    static func tipFailed(_ l: AppLanguage) -> String { t("購入できませんでした", "The purchase did not go through", l) }
    /// 1杯目と2杯目以降で言い方を変える
    static func tipGratitude(_ cups: Int, _ l: AppLanguage) -> String {
        cups <= 1
            ? t("奢ってくれてありがとうございました", "Thank you for the coffee", l)
            : t("\(cups) 回も奢ってくれてありがとうございました", "Thank you for the \(cups) coffees", l)
    }

    // 不具合の報告・要望
    static func feedbackBtn(_ l: AppLanguage) -> String {
        t("不具合の報告・要望を送る", "Report a problem or request a feature", l)
    }
    static func feedbackFallback(_ l: AppLanguage) -> String {
        t("メールが開かないときは \(Feedback.address) 宛に送ってください",
          "If Mail does not open, please email \(Feedback.address)", l)
    }
}
