import Foundation
import Testing
@testable import YurutoreCore

/// 配色は目分量で決めない。**条件を書いて、毎回測り直す。**
///
/// 黄と青は明度が同じでも輝度がまるで違うので、
/// 「明るいから黒文字が読めるはず」は当たらない。
struct PaletteTests {

    /// WCAG AA。マスの文字が読める下限
    let minText = 4.5
    /// 隣り合う段階が「別の色」に見える下限（OKLab上の距離）
    let minStep = 0.070
    /// 3段階目と4段階目だけは近くてよい。ただし同じには見えないこと
    let minTopStep = 0.050

    @Test("19パターンある")
    func count() {
        #expect(Palettes.all.count == 19)
        #expect(Set(Palettes.all.map(\.id)).count == Palettes.all.count)
    }

    @Test("どの段階でもマスの文字が読める")
    func textIsReadable() {
        for p in Palettes.all {
            for dark in [false, true] {
                for tier in DayTier.allCases {
                    let fill = p.fill(tier, dark: dark)
                    let ratio = ColorMath.contrast(fill, ColorMath.cellInk)
                    #expect(ratio >= minText,
                            "\(p.id)/\(dark ? "暗" : "明")/\(tier.rawValue) が \(ratio)")
                }
            }
        }
    }

    @Test("隣り合う段階が見分けられる")
    func stepsAreDistinct() {
        for p in Palettes.all {
            for dark in [false, true] {
                let c = p.colors(dark: dark).tiers
                for i in 0..<3 {
                    let d = ColorMath.difference(c[i], c[i + 1])
                    let floor = i == 2 ? minTopStep : minStep
                    #expect(d >= floor, "\(p.id)/\(dark ? "暗" : "明")/\(i + 1)-\(i + 2) が \(d)")
                }
            }
        }
    }

    /// 段階が上がるほど濃く（明るい地では暗く、暗い地では明るく）なること。
    /// 順番が入れ替わっていると、パッと見て優劣が分からなくなる。
    @Test("段階の順に、地から離れていく")
    func rankReadsAtAGlance() {
        for p in Palettes.all {
            let light = p.colors(dark: false).tiers.map(ColorMath.relativeLuminance)
            for i in 0..<3 {
                #expect(light[i] > light[i + 1], "\(p.id) 明るい地: \(i + 1)番目で順が崩れた")
            }
            let dark = p.colors(dark: true).tiers.map(ColorMath.relativeLuminance)
            for i in 0..<3 {
                #expect(dark[i] < dark[i + 1], "\(p.id) 暗い地: \(i + 1)番目で順が崩れた")
            }
        }
    }

    @Test("似すぎたパターンを並べない")
    func palettesAreDistinct() {
        for (i, a) in Palettes.all.enumerated() {
            for b in Palettes.all[(i + 1)...] {
                let top = ColorMath.difference(a.fill(.both, dark: false), b.fill(.both, dark: false))
                let mid = ColorMath.difference(a.fill(.half, dark: false), b.fill(.half, dark: false))
                #expect(top >= 0.06 || mid >= 0.06, "\(a.id) と \(b.id) が似すぎている")
            }
        }
    }

    @Test("文字とボタンの色が、地の上で読める")
    func inkIsReadable() {
        // systemGroupedBackground と secondarySystemGroupedBackground の実測値
        let grounds: [Bool: [UInt32]] = [false: [0xF2F2F7, 0xFFFFFF],
                                         true:  [0x1C1C1E, 0x2C2C2E]]
        for p in Palettes.all {
            for dark in [false, true] {
                let c = p.colors(dark: dark)
                for ground in grounds[dark]! {
                    #expect(ColorMath.contrast(c.ink, ground) >= minText, "\(p.id) の ink")
                }
                #expect(ColorMath.contrast(c.onInk, c.ink) >= minText, "\(p.id) の onInk")
            }
        }
    }

    @Test("知らない名前を渡しても既定に落ちる")
    func fallsBackToDefault() {
        #expect(Palettes.named("そんな色は無い").id == Palettes.defaultID)
        #expect(Palettes.named(nil).id == Palettes.defaultID)
        #expect(Palettes.named("grape").id == "grape")
    }

    @Test("1.1までの2色設定から引き継げる")
    func migratesFromOldTwoColors() {
        // 既定（うすい黄＋青）は、いちばん近い「砂と空」へ
        #expect(Palettes.migrating(fail: "yellow", pass: "blue") == "sand")
        // 同じ色を2つ選んでいた人は、その色の1色パターンへ
        #expect(Palettes.migrating(fail: "green", pass: "green") == "grass")
        #expect(Palettes.migrating(fail: "purple", pass: "purple") == "grape")
        // 保存が無くても落ちない
        #expect(Palettes.all.map(\.id).contains(Palettes.migrating(fail: nil, pass: nil)))
    }
}
