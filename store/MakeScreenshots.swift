import AppKit
import CoreGraphics
import Foundation

// App Store用のスクリーンショットを組む使い捨てスクリプト。
// 生のスクリーンショットの上にキャプションを載せ、6.9インチ(1320x2868)に収める。

// 既定は6.9インチ(1320x2868)。第3・第4引数で他のサイズにも出せる
let width = CommandLine.arguments.count > 3 ? Double(CommandLine.arguments[3])! : 1320.0
let height = CommandLine.arguments.count > 4 ? Double(CommandLine.arguments[4])! : 2868.0
let uiScale = width / 1320.0

struct Shot {
    let file: String
    let title: String
    let subtitle: String
}

let shots = [
    Shot(file: "01-month.png",    title: "今月、何日できたか", subtitle: "80点以上で合格。色が変わるので一目で分かります"),
    Shot(file: "02-input.png",    title: "押すのは部位だけ", subtitle: "歩数はヘルスケアから自動。重さも回数も入れません"),
    Shot(file: "03-year.png",     title: "1年を、まるごと見渡す", subtitle: "続いていることが目に見えます"),
    Shot(file: "04-settings.png", title: "自分の基準に合わせる", subtitle: "歩数の目安も運動の種類も、あとから変えられます"),
]

let inputDir = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2])
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

for shot in shots {
    guard let context = CGContext(
        data: nil, width: Int(width), height: Int(height),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("context") }

    // 背景。アプリアイコンの紺に合わせる
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [color(0xEAF0FA), color(0xC9D8F0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: height),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // 端末画面。角丸にして影を落とす
    let source = NSImage(contentsOf: inputDir.appendingPathComponent(shot.file))!
    var rect = CGRect(x: 0, y: 0, width: source.size.width, height: source.size.height)
    let cgSource = source.cgImage(forProposedRect: &rect, context: nil, hints: nil)!

    let shotWidth = width * 0.80
    let shotHeight = shotWidth * (height / width)
    let shotRect = CGRect(
        x: (width - shotWidth) / 2,
        y: -shotHeight * 0.06,
        width: shotWidth,
        height: shotHeight
    )
    let clip = CGPath(roundedRect: shotRect, cornerWidth: 56 * uiScale, cornerHeight: 56 * uiScale, transform: nil)

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -18),
        blur: 46,
        color: CGColor(red: 0.11, green: 0.16, blue: 0.13, alpha: 0.30)
    )
    context.addPath(clip)
    context.setFillColor(color(0xFFFFFF))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(clip)
    context.clip()
    context.draw(cgSource, in: shotRect)
    context.restoreGState()

    // キャプション
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let title = shot.title as NSString
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "HiraginoSans-W7", size: 84 * uiScale) ?? NSFont.systemFont(ofSize: 84 * uiScale, weight: .bold),
        .foregroundColor: NSColor(cgColor: color(0x18305C))!,
        .paragraphStyle: paragraph,
    ]
    let titleBox = CGRect(x: 70 * uiScale, y: height - 400 * uiScale, width: width - 140 * uiScale, height: 200 * uiScale)
    title.draw(in: titleBox, withAttributes: titleAttributes)

    let subtitle = shot.subtitle as NSString
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "HiraginoSans-W3", size: 44 * uiScale) ?? NSFont.systemFont(ofSize: 44 * uiScale),
        .foregroundColor: NSColor(cgColor: color(0x5A6B5F))!,
        .paragraphStyle: paragraph,
    ]
    let subtitleBox = CGRect(x: 80 * uiScale, y: height - 500 * uiScale, width: width - 160 * uiScale, height: 120 * uiScale)
    subtitle.draw(in: subtitleBox, withAttributes: subtitleAttributes)

    NSGraphicsContext.restoreGraphicsState()

    let output = outputDir.appendingPathComponent(shot.file)
    let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    print("wrote \(output.lastPathComponent)")
}
