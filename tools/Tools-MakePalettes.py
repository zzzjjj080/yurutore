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
    """hues = (h1, h2, h34). 明度と彩度は段階で固定し、色相だけ振る。"""
    h1, h2, h34 = hues
    if light:
        # 達成が進むほど濃く・鮮やかに。地（ほぼ白）から離れていく
        spec = [(0.945, 0.036, h1), (0.878, 0.095, h2),
                (0.760, 0.150, h34), (0.672, 0.185, h34)]
    else:
        # 暗い地の上では逆。進むほど明るく・鮮やかにする
        spec = [(0.655, 0.032, h1), (0.735, 0.080, h2),
                (0.818, 0.135, h34), (0.878, 0.170, h34)]
    # 彩度を落とす配色は、色相で差を付けられない。明度の幅を広げて段階を保つ
    if csc < 0.5:
        Ls = [0.960, 0.845, 0.730, 0.640] if light else [0.640, 0.730, 0.820, 0.905]
        spec = [(Ls[i], spec[i][1], spec[i][2]) for i in range(4)]
    out = []
    for (L, C, h) in spec:
        C *= csc
        rgb, _ = oklch_to_rgb255(L, C, h)
        # 黒文字が読めるまで明度を上げる。彩度ではなく明度で直す
        guard = 0
        while contrast(rgb) < MIN_TEXT and guard < 60:
            L += 0.006; guard += 1
            rgb, _ = oklch_to_rgb255(L, C, h)
        out.append(rgb)
    return out

PALETTES = [
    ("sky",      "空",       "Sky",           (245, 245, 245), 1.0),
    ("grass",    "草",       "Grass",         (150, 150, 150), 1.0),
    ("grape",    "葡萄",     "Grape",         (300, 300, 300), 1.0),
    ("apricot",  "杏",       "Apricot",       ( 58,  58,  58), 1.0),
    ("peach",    "桃",       "Peach",         (355, 355, 355), 1.0),
    ("lagoon",   "碧",       "Lagoon",        (192, 192, 192), 1.0),
    ("wheat",    "麦",       "Wheat",         ( 95,  95,  95), 1.0),
    ("brick",    "煉瓦",     "Brick",         ( 25,  25,  25), 1.0),
    ("stone",    "石",       "Stone",         (250, 250, 250), 0.20),
    ("leaf",     "若葉",     "Leaf",          (100, 100, 150), 1.0),
    ("water",    "水と青",   "Water & Blue",  (205, 205, 262), 1.0),
    ("rose",     "薔薇と菫", "Rose & Violet", (352, 352, 302), 1.0),
    ("sunfire",  "陽と炎",   "Sun & Fire",    ( 70,  70,  25), 1.0),
    ("mint",     "薄荷と碧", "Mint & Teal",   (142, 142, 198), 1.0),
    ("corn",     "粟と琥珀", "Corn & Amber",  (102, 102,  50), 1.0),
    ("lilac",    "藤と藍",   "Lilac & Indigo",(310, 310, 268), 1.0),
    ("sand",     "砂と空",   "Sand & Sky",    ( 72,  72, 246), 1.0),
    ("blossom",  "花と葉",   "Blossom & Leaf",(350, 350, 152), 1.0),
    ("straw",    "藁と葡萄", "Straw & Grape", ( 98,  98, 298), 1.0),
]



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
    il, idk = ink_for(hues[2], csc, True), ink_for(hues[2], csc, False)
    for nm, ink, bgs in (("light", il, (GROUPED_LIGHT, CARD_LIGHT)),
                         ("dark", idk, (GROUPED_DARK, CARD_DARK))):
        for bg in bgs:
            r = contrast(ink, rel_lum(bg))
            if r < 4.5: problems.append(f"{key}/{nm} ink {r:.2f}")
    on_l = (255, 255, 255)
    on_d = oklch_to_rgb255(0.18, 0.03, hues[2])[0]
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
