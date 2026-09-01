import SwiftUI
import YurutoreCore

/// 不具合の報告と要望の受け口。
///
/// **サーバーもフォームも持たない。** 標準のメールアプリを開くだけなので、
/// アプリ自身は通信せず、プライバシーポリシーに書き足すことがない。
///
/// 本文にバージョンと機種を先に入れておく。
/// 「どのバージョンですか」の往復が消えるので、ここがいちばん効く。
///
/// **このファイルは全アプリで同一。** アプリ名は Info.plist の表示名から取るので、
/// 書き換える場所は無い。
enum Feedback {
    static let address = "zzzjjj080@gmail.com"

    /// 画面に出ているアプリ名（`INFOPLIST_KEY_CFBundleDisplayName`）
    static var appName: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? "App"
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    /// `iPhone18,4` のような機種識別子。表示名より、こちらのほうが特定できる。
    static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// `UIDevice` は MainActor に閉じているので、こちらを使う。
    /// どこから呼んでも警告が出ない。
    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.patchVersion == 0
            ? "\(v.majorVersion).\(v.minorVersion)"
            : "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    static func mailURL(english: Bool = false) -> URL? {
        let subject = english
            ? "\(appName) \(appVersion) — problem or request"
            : "\(appName) \(appVersion) の不具合・要望"
        let keep = english
            ? "--- Please keep the lines below ---"
            : "--- ここから下は消さずに送ってください ---"
        let body = """


        \(keep)
        \(english ? "App" : "アプリ"): \(appName) \(appVersion)
        iOS: \(osVersion)
        \(english ? "Device" : "機種"): \(deviceModel)
        ------------------------------------
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

/// 設定に置く「不具合の報告・要望を送る」。ゆるトレ日記の見た目に合わせた日英2言語版。
struct FeedbackButtonYurutore: View {
    let lang: AppLanguage
    let accent: Color
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Haptics.light()
                if let url = Feedback.mailURL(english: lang == .en) { openURL(url) }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(accent)
                    Text(L.feedbackBtn(lang))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(11)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                // Spacer は描画を持たないので、これが無いと余白を押しても反応しない
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sendFeedback")

            // メールアプリを設定していない端末では mailto: が無反応になる
            Text(L.feedbackFallback(lang))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
