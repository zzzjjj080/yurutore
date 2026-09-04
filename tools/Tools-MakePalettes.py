# カレンダーの4段階配色を作る。OKLCH で組んで sRGB に落とし、
# 黒文字とのコントラストを実測してから採用する。
import math, json

def oklch_to_srgb(L, C, h_deg):
    h = math.radians(h_deg)
    a, b = C*math.cos(h), C*math.sin(h)
    l_ = L + 0.3963377774*a + 0.2158037573*b
    m_ = L - 0.1055613458*a - 0.0638541728*b
    s_ = L - 0.0894841775*a - 1.2914855480*b
    l, m, s = l_**3, m_**3, s_**3
    r = 4.0767416621*l - 3.3077115913*m + 0.2309699292*s
    g = -1.2684380046*l + 2.6097574011*m - 0.3413193965*s
    bb = -0.0041960863*l - 0.7034186147*m + 1.7076147010*s
    return r, g, bb

def in_gamut(lin):
    return all(-0.0005 <= c <= 1.0005 for c in lin)

def encode(c):
    c = min(1.0, max(0.0, c))
    v = 12.92*c if c <= 0.0031308 else 1.055*(c**(1/2.4)) - 0.055
    return int(round(v*255))

def oklch_to_rgb255(L, C, h):
    # ガモット外なら彩度だけ落とす。明度は動かさない（段階の順序が崩れるため）
    lo, hi = 0.0, C
    if not in_gamut(oklch_to_srgb(L, C, h)):
        for _ in range(40):
            mid = (lo+hi)/2
            if in_gamut(oklch_to_srgb(L, mid, h)): lo = mid
            else: hi = mid
        C = lo
    lin = oklch_to_srgb(L, C, h)
    return tuple(encode(c) for c in lin), C

def rel_lum(rgb):
    def f(v):
        c = v/255
        return c/12.92 if c <= 0.03928 else ((c+0.055)/1.055)**2.4
    r, g, b = (f(v) for v in rgb)
    return 0.2126*r + 0.7152*g + 0.0722*b

INK = (20, 24, 30)          # マスの文字。両テーマ共通
INK_L = rel_lum(INK)

def contrast(rgb, other_l=INK_L):
    a, b = rel_lum(rgb), other_l
    hi, lo = max(a, b), min(a, b)
    return (hi+0.05)/(lo+0.05)

def oklab_of(rgb):
    def f(v):
        c = v/255
        return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4
    r, g, b = (f(v) for v in rgb)
    l = (0.4122214708*r + 0.5363325363*g + 0.0514459929*b)**(1/3)
    m = (0.2119034982*r + 0.6806995451*g + 0.1073969566*b)**(1/3)
    s = (0.0883024619*r + 0.2817188376*g + 0.6299787005*b)**(1/3)
    return (0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
            1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
            0.0259040371*l + 0.7827717662*m - 0.8086757660*s)

def dE(a, b):
    x, y = oklab_of(a), oklab_of(b)
    return math.dist(x, y)

MIN_TEXT = 4.6        # 黒文字が読める下限（WCAG AA 4.5 に余裕を持たせる）

def build(hues, light=True, csc=1.0):
    """hues = (hA, hB)。hA = 40〜79点の色、hB = 80点以上の色。

    1段階目はどのパターンでもグレー。「記録はあるが、まだ何も越えていない日」を
    色で語らせない。2段階目と3段階目のあいだ（＝80点の境目）だけ色相が変わる。
    """
    hA, hB = hues
    GREY_H = 250          # ほんの少し寒色寄りの無彩色
    if light:
        # 明るい地。進むほど暗く・鮮やかに
        spec = [(0.895, 0.010, GREY_H), (0.845, 0.110, hA),
                (0.700, 0.170, hB),     (0.625, 0.200, hB)]
    else:
        # 暗い地。進むほど明るく・鮮やかに
        spec = [(0.625, 0.010, GREY_H), (0.685, 0.090, hA),
                (0.840, 0.155, hB),     (0.900, 0.185, hB)]
    out = []
    for (L, C, h) in spec:
        rgb, _ = oklch_to_rgb255(L, C, h)
        # 黒文字が読めるまで明度を上げる。彩度ではなく明度で直す
        guard = 0
        while contrast(rgb) < MIN_TEXT and guard < 60:
            L += 0.006
            guard += 1
            rgb, _ = oklch_to_rgb255(L, C, h)
        out.append(rgb)
    return out

# 色相から呼び名を引く。名前を手で付けると、組み合わせを変えたときにずれる。
HUE_NAMES = [(15, "薔薇", "Rose"), (40, "煉瓦", "Brick"), (70, "杏", "Apricot"),
             (105, "麦", "Wheat"), (140, "若葉", "Lime"), (170, "草", "Grass"),
             (200, "薄荷", "Mint"), (225, "水", "Water"), (255, "空", "Sky"),
             (285, "藍", "Indigo"), (315, "葡萄", "Grape"), (340, "紅", "Magenta"),
             (361, "桃", "Peach")]

def hue_name(h):
    for limit, ja, en in HUE_NAMES:
        if h % 360 < limit: return ja, en
    return HUE_NAMES[-1][1], HUE_NAMES[-1][2]

def hue_gap(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)

def per_palette_problems(hues):
    """1パターン単体の条件。破るものは候補から外す。"""
    bad = []
    if hue_gap(hues[0], hues[1]) < 60: bad.append("色相が近い")
    for light in (True, False):
        c = build(hues, light)
        for x in c:
            if contrast(x) < MIN_TEXT: bad.append("文字が読めない")
        for i in range(3):
            floor = 0.055 if i == 2 else 0.075
            if dE(c[i], c[i+1]) < floor: bad.append(f"{i+1}-{i+2}が近い")
        gap = dE(c[1], c[2])
        if gap < 0.20: bad.append("80点の境目が弱い")
        if gap <= max(dE(c[0], c[1]), dE(c[2], c[3])): bad.append("境目が一番の差でない")
    return bad

def too_similar(a, b):
    ca, cb = build(a, True), build(b, True)
    return dE(ca[1], cb[1]) < 0.06 and dE(ca[2], cb[2]) < 0.06

# 候補を色相の総当たりで作り、条件を満たすものから離れている順に採る
CANDIDATES = [(hA, (hA + off) % 360)
              for hA in range(0, 360, 15)
              for off in (150, 165, 180, 195, 210)]

PALETTES, taken_names = [], set()
for hues in CANDIDATES:
    if per_palette_problems(hues): continue
    ja = f"{hue_name(hues[0])[0]}と{hue_name(hues[1])[0]}"
    en = f"{hue_name(hues[0])[1]} & {hue_name(hues[1])[1]}"
    if ja in taken_names: continue
    if any(too_similar(hues, p[3]) for p in PALETTES): continue
    key = f"{hue_name(hues[0])[1]}-{hue_name(hues[1])[1]}".lower()
    PALETTES.append((key, ja, en, hues, 1.0))
    taken_names.add(ja)

# 既定は 1.1 の「うすい黄＋青」に一番近いもの
# 総当たりで作った候補から、色の傾向がなるべく散るように8つだけ残す。
# 多すぎると選べない。自分で決めたい人には「自分で選ぶ」がある。
KEEP = ["wheat-sky", "rose-grass", "sky-brick", "mint-peach",
        "indigo-lime", "water-apricot", "wheat-grape", "grass-magenta"]
by_key = {p[0]: p for p in PALETTES}
missing = [k for k in KEEP if k not in by_key]
if missing: raise SystemExit(f"残したいパターンが候補に無い: {missing}")
PALETTES = [by_key[k] for k in KEEP]




GROUPED_LIGHT = (242, 242, 247)   # systemGroupedBackground
GROUPED_DARK  = ( 28,  28,  30)
CARD_LIGHT    = (255, 255, 255)   # secondarySystemGroupedBackground
CARD_DARK     = ( 44,  44,  46)

def ink_for(h, csc, light):
    """文字やボタンに使う色。カードの上に乗るので、地とのコントラストで決める。"""
    bgs = [rel_lum(GROUPED_LIGHT), rel_lum(CARD_LIGHT)] if light else [rel_lum(GROUPED_DARK), rel_lum(CARD_DARK)]
    L = 0.55 if light else 0.80
    C = 0.16 * csc if csc >= 0.5 else 0.02
    for _ in range(90):
        rgb, _c = oklch_to_rgb255(L, C, h)
        if all(contrast(rgb, bg) >= 4.5 for bg in bgs): return rgb
        L += -0.006 if light else 0.006
        if L <= 0.06 or L >= 0.99: break
    return oklch_to_rgb255(L, C, h)[0]

result = []
problems = []
for key, ja, en, hues, csc in PALETTES:
    lt = build(hues, True, csc)
    dk = build(hues, False, csc)
    for theme, cols in (("light", lt), ("dark", dk)):
        for i, c in enumerate(cols):
            r = contrast(c)
            if r < 4.5: problems.append(f"{key}/{theme}/{i+1} 文字 {r:.2f}")
        for i in range(3):
            d = dE(cols[i], cols[i+1])
            floor = 0.055 if i == 2 else 0.075   # 3と4は近くてよい
            if d < floor: problems.append(f"{key}/{theme}/{i+1}-{i+2} 差 {d:.3f}")
        gap = dE(cols[1], cols[2])
        if gap < 0.20: problems.append(f"{key}/{theme} 80点の境目が弱い {gap:.3f}")
        if gap <= max(dE(cols[0], cols[1]), dE(cols[2], cols[3])):
            problems.append(f"{key}/{theme} 80点の境目が一番の差でない")
        _L, _a, _b = oklab_of(cols[0])
        if math.hypot(_a, _b) > 0.020: problems.append(f"{key}/{theme} 1段階目が無彩色でない")
    if min(abs(hues[0]-hues[1]), 360-abs(hues[0]-hues[1])) < 60:
        problems.append(f"{key} 80点の前後で色相が近い")
    il, idk = ink_for(hues[1], csc, True), ink_for(hues[1], csc, False)
    for nm, ink, bgs in (("light", il, (GROUPED_LIGHT, CARD_LIGHT)),
                         ("dark", idk, (GROUPED_DARK, CARD_DARK))):
        for bg in bgs:
            r = contrast(ink, rel_lum(bg))
            if r < 4.5: problems.append(f"{key}/{nm} ink {r:.2f}")
    on_l = (255, 255, 255)
    on_d = oklch_to_rgb255(0.18, 0.03, hues[1])[0]
    if contrast(on_l, rel_lum(il)) < 4.5: problems.append(f"{key}/light onInk {contrast(on_l, rel_lum(il)):.2f}")
    if contrast(on_d, rel_lum(idk)) < 4.5: problems.append(f"{key}/dark onInk {contrast(on_d, rel_lum(idk)):.2f}")
    result.append({"key": key, "ja": ja, "en": en, "light": lt, "dark": dk,
                   "inkL": il, "inkD": idk, "onInkL": on_l, "onInkD": on_d})

# パターンどうしが似すぎていないか（3段階目＝その配色の看板の色で見る）
for i in range(len(result)):
    for j in range(i+1, len(result)):
        d = dE(result[i]["light"][2], result[j]["light"][2])
        d2 = dE(result[i]["light"][1], result[j]["light"][1])
        if d < 0.06 and d2 < 0.06:
            problems.append(f"似すぎ {result[i]['key']} と {result[j]['key']} ({d:.3f}/{d2:.3f})")

print(json.dumps(result, ensure_ascii=False))
print("---PROBLEMS---")
print("\n".join(problems) if problems else "なし")
