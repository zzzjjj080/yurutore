import Foundation

/// いま動いているのがどのビルドかを、画面から確かめられるようにする。
///
/// **印は手で増やさない。** インストール用スクリプトが
/// `YT_BUILD_STAMP` を渡し、Info.plist 経由でここへ入る。
/// 手で増やす方式だと、増やし忘れたときに印が嘘をつく（引き継ぎ書 4-145）。
enum BuildStamp {
    /// 例: `1.3 (7) · b41 09/16 11:30`
    /// Xcode から直接ビルドしたときは印が空になるので、版番号だけ出す。
    static var text: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let head = "\(version) (\(build))"
        guard let stamp = (info?["YTBuildStamp"] as? String)?
            .trimmingCharacters(in: .whitespaces), !stamp.isEmpty else { return head }
        return "\(head) · \(stamp)"
    }
}
