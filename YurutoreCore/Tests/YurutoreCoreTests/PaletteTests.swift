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

    @Test("プリセットは8つ")
    func count() {
        #expect(Palettes.all.count == 8)
        #expect(Set(Palettes.all.map(\.id)).count == Palettes.all.count)
        #expect(Set(Palettes.all.map(\.ja)).count == Palettes.all.count)
    }

    /// まだ何も越えていない日を、色で語らせない。
    @Test("39点までは、どのパターンでも無彩色")
    func lowestIsGrey() {
        for p in Palettes.all {
            for dark in [false, true] {
                let c = ColorMath.chroma(p.fill(.low, dark: dark))
                #expect(c <= 0.020, "\(p.id)/\(dark ? "暗" : "明") の1段階目が \(c)")
            }
        }
    }

    /// **合否がいちばん見分けたいところ。** 80点の前後は色相から変える。
    @Test("80点の境目が、いちばんはっきり離れている")
    func passBoundaryIsTheBiggestBreak() {
        for p in Palettes.all {
            for dark in [false, true] {
                let c = p.colors(dark: dark).tiers
                let gap = ColorMath.difference(c[1], c[2])
                let others = [ColorMath.difference(c[0], c[1]),
                              ColorMath.difference(c[2], c[3])]
                #expect(gap >= 0.20, "\(p.id)/\(dark ? "暗" : "明") の境目が \(gap)")
                #expect(gap > others.max()!, "\(p.id)/\(dark ? "暗" : "明") で境目が一番の差でない")
                #expect(ColorMath.hueGap(c[1], c[2]) >= 60,
                        "\(p.id)/\(dark ? "暗" : "明") で80点の前後の色相が近い")
            }
        }
    }

    /// 単色の濃淡だけのパターンは置かない。合否の境目が読めないため。
    @Test("同じ色相の濃淡だけのパターンは無い")
    func noSingleHuePalettes() {
        for p in Palettes.all {
            let c = p.colors(dark: false).tiers
            #expect(ColorMath.hueGap(c[1], c[2]) >= 60, "\(p.id) が単色に近い")
        }
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
                let top = ColorMath.difference(a.fill(.pass, dark: false), b.fill(.pass, dark: false))
                let mid = ColorMath.difference(a.fill(.mid, dark: false), b.fill(.mid, dark: false))
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

    // MARK: - 自分で選んだ4色

    @Test("選んだ4色が、そのままマスの色になる")
    func customUsesTheChosenColors() {
        let picked: [UInt32] = [0xEEEEEE, 0xFFD79A, 0x7FC4FF, 0x1E88E5]
        let p = Palettes.custom(picked, ja: "自分の色", en: "Custom")
        for dark in [false, true] {
            #expect(p.colors(dark: dark).tiers == picked, "\(dark ? "暗" : "明") で色が変わっている")
        }
        #expect(p.id == Palettes.customID)
    }

    /// 文字やボタンの色は選ばせない。地の上で読める明るさまで自動で動かす。
    @Test("自分で選んでも、文字とボタンの色は読める")
    func customInkStaysReadable() {
        let grounds: [Bool: [UInt32]] = [false: [0xF2F2F7, 0xFFFFFF],
                                         true:  [0x1C1C1E, 0x2C2C2E]]
        // わざと極端な色を渡す。白・黒・原色でも破綻しないこと
        let samples: [[UInt32]] = [[0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
                                   [0x000000, 0x000000, 0x000000, 0x000000],
                                   [0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00],
                                   [0x101010, 0xF0F0F0, 0x808080, 0x00FFFF]]
        for picked in samples {
            let p = Palettes.custom(picked, ja: "自分の色", en: "Custom")
            for dark in [false, true] {
                let c = p.colors(dark: dark)
                for ground in grounds[dark]! {
                    #expect(ColorMath.contrast(c.ink, ground) >= 4.5,
                            "\(picked) の ink が \(ColorMath.contrast(c.ink, ground))")
                }
                #expect(ColorMath.contrast(c.onInk, c.ink) >= 4.5, "\(picked) の onInk")
            }
        }
    }

    @Test("4色に足りない保存を読んでも落ちない")
    func customSurvivesShortSaves() {
        #expect(Palettes.normalizedCustom([]).count == 4)
        #expect(Palettes.normalizedCustom([0x112233]).count == 4)
        #expect(Palettes.normalizedCustom([0x112233])[0] == 0x112233)
        // 足りないぶんは既定から埋める
        let base = Palettes.named(Palettes.defaultID).colors(dark: false).tiers
        #expect(Palettes.normalizedCustom([0x112233])[3] == base[3])
    }

    /// 止めはしない。気づけるようにだけしておく。
    @Test("危ない組み合わせを教えてくれる")
    func customIssuesAreReported() {
        // プリセットと同じ条件を満たす色なら、何も言わない
        let ok = Palettes.named("wheat-sky").colors(dark: false).tiers
        #expect(Palettes.issues(with: ok).isEmpty)

        // 黒文字が読めない濃さ
        let tooDark: [UInt32] = [0x101010, 0x202020, 0x303030, 0x404040]
        #expect(Palettes.issues(with: tooDark).contains(.textUnreadable(.low)))

        // 4つとも同じ色。隣が見分けられず、80点の境目も無い
        let flat = [UInt32](repeating: 0xDDDDDD, count: 4)
        let issues = Palettes.issues(with: flat)
        #expect(issues.contains(.tooClose(.low, .mid)))
        #expect(issues.contains(.weakPassBoundary))
    }

    @Test("知らない名前を渡しても既定に落ちる")
    func fallsBackToDefault() {
        #expect(Palettes.named("そんな色は無い").id == Palettes.defaultID)
        #expect(Palettes.named(nil).id == Palettes.defaultID)
        #expect(Palettes.named("rose-grass").id == "rose-grass")
    }

    /// 引き継ぎは「80点以上に選んでいた色」で決める。そこが合否の境目なので、
    /// 印象がいちばん変わらない。
    @Test("1.1までの2色設定から引き継げる")
    func migratesFromOldTwoColors() {
        #expect(Palettes.migrating(fail: "yellow", pass: "blue") == Palettes.defaultID)
        #expect(Palettes.migrating(fail: "yellow", pass: "green") == "rose-grass")
        #expect(Palettes.migrating(fail: "blue", pass: "purple") == "wheat-grape")
        // どの答えも実在すること。保存が無くても落ちないこと
        for pass in ["blue", "green", "purple", "orange", "yellow", "そんな色は無い"] {
            let id = Palettes.migrating(fail: nil, pass: pass)
            #expect(Palettes.all.map(\.id).contains(id), "\(pass) の行き先が無い")
        }
        #expect(Palettes.all.map(\.id).contains(Palettes.migrating(fail: nil, pass: nil)))
    }
}
