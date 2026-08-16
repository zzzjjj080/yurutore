import AppKit
import CoreGraphics
import Foundation

// ゆるトレ日記のアプリアイコン。
//
// このアプリの核心は「カレンダーが埋まっていくこと」なので、
// 月カレンダーのマスをそのままモチーフにする。
// ホーム画面では60px程度まで縮むため、細部ではなく塊で見せる。

let size = 1024.0

guard let context = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("context") }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

// アプリの既定色に合わせる。合格＝青、未達＝黄。
let passColor  = color(0x6DA4F0)
let passDeep   = color(0x2563EB)
let failColor  = color(0xF0C94A)
let emptyColor = color(0xFFFFFF, 0.20)

// 背景。濃紺から藍へ。マスの青と黄が両方乗る地色にする。
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [color(0x1E3A6E), color(0x0E1B33)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0),
                           options: [])

// 角丸でマスクされるので、全体を少し縮めて端に余白を残す
context.translateBy(x: size / 2, y: size / 2)
context.scaleBy(x: 0.86, y: 0.86)
context.translateBy(x: -size / 2, y: -size / 2)

// MARK: - カレンダーのマス

// 4列×4行。7列だと60pxまで縮んだとき潰れて見えないので、あえて粗くする。
let cols = 4, rows = 4
let gap  = 30.0
let board = 620.0
let cell  = (board - gap * Double(cols - 1)) / Double(cols)
let originX = (size - board) / 2
let originY = (size - board) / 2 - 40

// 埋まっているマスの配置。左上から右下へ「続いている」ように見せる。
// 2 は合格（青）、1 は未達（黄）、0 は空。
let pattern: [[Int]] = [
    [2, 2, 1, 2],
    [0, 2, 2, 1],
    [2, 1, 2, 0],
    [1, 2, 0, 0],
]

for r in 0..<rows {
    for c in 0..<cols {
        let x = originX + Double(c) * (cell + gap)
        // 配列の先頭を上に描くため、y を反転させる
        let y = originY + Double(rows - 1 - r) * (cell + gap)
        let rect = CGRect(x: x, y: y, width: cell, height: cell)
        let path = CGPath(roundedRect: rect, cornerWidth: 34, cornerHeight: 34, transform: nil)

        switch pattern[r][c] {
        case 2: context.setFillColor(passColor)
        case 1: context.setFillColor(failColor)
        default: context.setFillColor(emptyColor)
        }
        context.addPath(path)
        context.fillPath()
    }
}

// MARK: - チェック

// 「合格した」ことの記号。右下のマスに重ねて、カレンダー上の出来事だと分かるようにする。
let checkCenter = CGPoint(x: originX + board - cell / 2 - 6,
                          y: originY + cell / 2 + 6)
let ring = 132.0

context.setFillColor(passDeep)
context.addPath(CGPath(ellipseIn: CGRect(x: checkCenter.x - ring / 2,
                                         y: checkCenter.y - ring / 2,
                                         width: ring, height: ring), transform: nil))
context.fillPath()

let check = CGMutablePath()
check.move(to: CGPoint(x: checkCenter.x - 34, y: checkCenter.y + 2))
check.addLine(to: CGPoint(x: checkCenter.x - 8, y: checkCenter.y - 26))
check.addLine(to: CGPoint(x: checkCenter.x + 38, y: checkCenter.y + 28))

context.setStrokeColor(color(0xFFFFFF))
context.setLineWidth(24)
context.setLineCap(.round)
context.setLineJoin(.round)
context.addPath(check)
context.strokePath()

// MARK: - 書き出し

guard let image = context.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(Int(size))x\(Int(size)))")
