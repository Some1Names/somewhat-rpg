"""Draws docs/world-map.png: an illustrated overview of Region 1's planned layout.

Theme: a post-apocalyptic present-day world, with old-Japan (Edo / Sengoku) pieces bleeding in
through rifts. The six mainland regions follow the owner's sketch; every other zone, road, point
of interest and level band is a proposal. Not generated from the Studio parts.
Run: python tools/draw_world_map.py
"""
import math
import random
from PIL import Image, ImageDraw, ImageFont

SS = 2
W, H = 1830, 1700
random.seed(11)

MODERN = (255, 250, 235)
OLD = (255, 214, 150)
RIFT = (214, 90, 255)

def P(x, y):
    return ((x - 250) * 1.4 + 80) * SS, ((y + 170) * 1.4 + 130) * SS

def pts(poly):
    return [P(x, y) for x, y in poly]

def font(size, bold=False, italic=False):
    name = "georgia" + ("bi" if bold and italic else "b" if bold else "i" if italic else "") + ".ttf"
    return ImageFont.truetype("C:/Windows/Fonts/" + name, int(size * SS))

img = Image.new("RGB", (W * SS, H * SS), (28, 62, 96))
d = ImageDraw.Draw(img, "RGBA")

for i in range(0, H * SS, 14 * SS):
    shade = int(8 * math.sin(i / (60.0 * SS)))
    d.rectangle([0, i, W * SS, i + 14 * SS], fill=(28 + shade, 62 + shade, 96 + shade, 255))
for _ in range(1400):
    x, y = random.randint(0, W * SS), random.randint(0, H * SS)
    l = random.randint(12, 30) * SS
    d.line([x, y, x + l, y], fill=(110, 150, 180, 70), width=SS)

# ---- zones -----------------------------------------------------------------------------------------
LAND = [(515, 120), (860, 110), (860, 262), (990, 262), (990, 430), (930, 430), (920, 600),
        (585, 600), (585, 432), (480, 432), (480, 350), (515, 350)]

ZONES = {
    "mountain": dict(poly=[(930, 50), (1010, 45), (1090, 100), (1105, 190), (1040, 255), (960, 250), (905, 170)], fill=(140, 134, 124)),
    "carnival": dict(poly=[(410, 612), (645, 612), (645, 728), (410, 728)], fill=(160, 150, 168)),
    "plant":    dict(poly=[(540, -140), (720, -155), (880, -120), (890, 0), (860, 48), (718, 48), (525, 118), (510, 0)], fill=(124, 128, 118)),
    "airfield": dict(poly=[(300, 430), (480, 432), (480, 540), (400, 570), (300, 540), (275, 490)], fill=(150, 150, 140)),
    "badlands": dict(poly=[(990, 262), (1180, 230), (1330, 300), (1360, 470), (1220, 560), (990, 540), (990, 430)], fill=(176, 100, 70)),
    "summit":   dict(poly=[(1090, 100), (1260, -60), (1400, 0), (1390, 170), (1330, 300), (1180, 230), (1105, 190)], fill=(112, 106, 130)),
    "coast":    dict(poly=[(930, 540), (990, 540), (1220, 560), (1180, 720), (1000, 780), (920, 700), (920, 600)], fill=(220, 204, 156)),
    "bamboo":   dict(poly=[(585, 600), (733, 600), (920, 600), (920, 700), (800, 790), (640, 760), (645, 612)], fill=(118, 160, 92)),
}
ALL_POLYS = [LAND] + [z["poly"] for z in ZONES.values()]

for poly in ALL_POLYS:
    p = pts(poly)
    d.polygon(p, fill=(0, 0, 0, 55))
    for grow, col in ((22, (70, 125, 155, 120)), (12, (150, 190, 200, 170))):
        d.line(p + [p[0]], fill=col, width=grow * SS, joint="curve")
for poly in ALL_POLYS:
    p = pts(poly)
    d.polygon(p, fill=(226, 212, 168))
    d.line(p + [p[0]], fill=(226, 212, 168), width=10 * SS, joint="curve")
d.polygon(pts(LAND), fill=(108, 142, 92), outline=(108, 142, 92))
for z in ZONES.values():
    d.polygon(pts(z["poly"]), fill=z["fill"], outline=z["fill"], width=2 * SS)

def inside(poly, x, y):
    n, ok, j = len(poly), False, len(poly) - 1
    for i in range(n):
        xi, yi = poly[i]; xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            ok = not ok
        j = i
    return ok

def scatter(poly, count, fn, keep_out=()):
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    placed, tries = 0, 0
    while placed < count and tries < count * 60:
        tries += 1
        x = random.uniform(min(xs), max(xs)); y = random.uniform(min(ys), max(ys))
        if inside(poly, x, y) and not any(math.hypot(x - kx, y - ky) < kr for kx, ky, kr in keep_out):
            fn(*P(x, y)); placed += 1

# ---- icons -----------------------------------------------------------------------------------------
def tree(X, Y, col=(38, 96, 48), edge=(24, 64, 34)):
    r = random.randint(7, 11) * SS
    d.ellipse([X - r, Y + r * 0.5, X + r, Y + r * 0.9], fill=(0, 0, 0, 60))
    d.rectangle([X - SS, Y, X + SS, Y + r * 0.7], fill=(90, 62, 40))
    d.ellipse([X - r, Y - r * 1.4, X + r, Y + r * 0.3], fill=col, outline=edge, width=SS)
    d.ellipse([X - r * 0.5, Y - r * 1.2, X + r * 0.1, Y - r * 0.6], fill=(80, 150, 80))

def dead_tree(X, Y):
    h = random.randint(14, 22) * SS
    d.line([X, Y, X, Y - h], fill=(70, 56, 46), width=2 * SS)
    d.line([X, Y - h * 0.6, X + 7 * SS, Y - h * 0.95], fill=(70, 56, 46), width=SS)
    d.line([X, Y - h * 0.45, X - 7 * SS, Y - h * 0.8], fill=(70, 56, 46), width=SS)

def ruin_house(X, Y, w=15):
    w *= SS
    d.rectangle([X, Y, X + w, Y + w * 0.7], fill=(176, 168, 158), outline=(60, 54, 50), width=SS)
    d.polygon([(X - 2 * SS, Y), (X + w * 0.35, Y - w * 0.45), (X + w * 0.55, Y - w * 0.2), (X + w + 2 * SS, Y)], fill=(104, 92, 88), outline=(60, 54, 50))
    d.rectangle([X + w * 0.3, Y + w * 0.2, X + w * 0.5, Y + w * 0.5], fill=(40, 36, 36))

def edo_house(X, Y, w=14):
    w *= SS
    d.rectangle([X, Y, X + w, Y + w * 0.7], fill=(222, 196, 150), outline=(70, 50, 36), width=SS)
    d.polygon([(X - 4 * SS, Y + 2 * SS), (X + w / 2, Y - w * 0.5), (X + w + 4 * SS, Y + 2 * SS)], fill=(58, 52, 54), outline=(30, 24, 24))
    d.ellipse([X + w * 0.4, Y + w * 0.25, X + w * 0.6, Y + w * 0.45], fill=(230, 70, 50))

def tent(X, Y, col=(70, 110, 160)):
    s = 12 * SS
    d.polygon([(X - s, Y + s * 0.7), (X, Y - s * 0.8), (X + s, Y + s * 0.7)], fill=col, outline=(24, 36, 54))
    d.polygon([(X - s * 0.25, Y + s * 0.7), (X, Y - s * 0.1), (X + s * 0.25, Y + s * 0.7)], fill=(20, 28, 40))

def campfire(X, Y):
    d.ellipse([X - 8 * SS, Y - 8 * SS, X + 8 * SS, Y + 8 * SS], fill=(255, 150, 50, 90))
    d.ellipse([X - 3 * SS, Y - 3 * SS, X + 3 * SS, Y + 3 * SS], fill=(255, 190, 70))

def ruin_block(X, Y, w, h):
    d.rectangle([X + 4 * SS, Y + 4 * SS, X + w + 4 * SS, Y + h + 4 * SS], fill=(0, 0, 0, 70))
    d.rectangle([X, Y, X + w, Y + h], fill=(168, 172, 186), outline=(60, 62, 80), width=SS)
    notch = [(X, Y), (X + w * 0.25, Y - 6 * SS), (X + w * 0.45, Y + 3 * SS), (X + w * 0.7, Y - 9 * SS), (X + w, Y - 2 * SS), (X + w, Y)]
    d.polygon(notch, fill=(190, 194, 208), outline=(60, 62, 80))
    for k in range(int(h / (9 * SS))):
        d.rectangle([X + 3 * SS, Y + 5 * SS + k * 9 * SS, X + w - 3 * SS, Y + 8 * SS + k * 9 * SS], fill=(52, 58, 74, 140))

def peak(X, Y, s, snowcap=True, col=(118, 110, 100)):
    d.polygon([(X - s, Y + s * 0.8), (X, Y - s), (X + s, Y + s * 0.8)], fill=col, outline=(60, 54, 48))
    d.polygon([(X, Y - s), (X + s, Y + s * 0.8), (X + s * 0.15, Y + s * 0.8)], fill=(80, 74, 68))
    if snowcap:
        d.polygon([(X - s * 0.32, Y - s * 0.4), (X, Y - s), (X + s * 0.32, Y - s * 0.4), (X, Y - s * 0.2)], fill=(245, 245, 250))

def mesa(X, Y):
    w = random.randint(12, 24) * SS; h = random.randint(8, 16) * SS
    d.polygon([(X - w, Y + h), (X - w * 0.8, Y - h), (X + w * 0.8, Y - h), (X + w, Y + h)], fill=(150, 78, 52), outline=(90, 42, 28))
    d.polygon([(X - w * 0.8, Y - h), (X + w * 0.8, Y - h), (X + w * 0.6, Y - h - 5 * SS), (X - w * 0.6, Y - h - 5 * SS)], fill=(205, 128, 90))

def bamboo(X, Y):
    for k in range(4):
        x = X + k * 4 * SS
        d.line([x, Y, x, Y - random.randint(16, 28) * SS], fill=(52, 120, 56), width=2 * SS)
        d.line([x - 3 * SS, Y - 8 * SS, x + 3 * SS, Y - 8 * SS], fill=(160, 210, 120), width=SS)

def dune(X, Y):
    w = random.randint(14, 26) * SS
    d.arc([X - w, Y - w * 0.5, X + w, Y + w * 0.5], 200, 340, fill=(180, 150, 90), width=2 * SS)

def lantern(X, Y):
    d.line([X, Y, X, Y - 12 * SS], fill=(90, 60, 40), width=SS)
    d.ellipse([X - 4 * SS, Y - 20 * SS, X + 4 * SS, Y - 10 * SS], fill=(230, 70, 50), outline=(110, 30, 20))

def crystal(X, Y, s):
    d.polygon([(X, Y - s * 1.4), (X + s * 0.5, Y), (X, Y + s * 0.4), (X - s * 0.5, Y)], fill=(170, 150, 235), outline=(70, 50, 140))

def torii(X, Y, s=1.0):
    h = 26 * SS * s; w = 22 * SS * s
    red, dark = (200, 48, 40), (90, 20, 18)
    d.rectangle([X - w * 0.7, Y - h, X - w * 0.7 + 4 * SS * s, Y], fill=red, outline=dark)
    d.rectangle([X + w * 0.7 - 4 * SS * s, Y - h, X + w * 0.7, Y], fill=red, outline=dark)
    d.rectangle([X - w * 0.95, Y - h - 4 * SS * s, X + w * 0.95, Y - h + 3 * SS * s], fill=(40, 30, 30), outline=dark)
    d.rectangle([X - w * 0.7, Y - h * 0.7, X + w * 0.7, Y - h * 0.7 + 3 * SS * s], fill=red, outline=dark)

def castle(X, Y, s=1.0):
    w = 54 * SS * s
    d.rectangle([X - w / 2 - 8 * SS, Y + 6 * SS, X + w / 2 + 8 * SS, Y + 18 * SS * s], fill=(120, 116, 112), outline=(50, 46, 44), width=SS)
    for k, ww in enumerate((1.0, 0.72, 0.46)):
        top = Y - k * 20 * SS * s
        d.rectangle([X - w * ww / 2, top - 14 * SS * s, X + w * ww / 2, top + 6 * SS], fill=(244, 240, 228), outline=(60, 56, 52), width=SS)
        d.polygon([(X - w * ww / 2 - 9 * SS, top - 14 * SS * s), (X, top - 28 * SS * s), (X + w * ww / 2 + 9 * SS, top - 14 * SS * s)], fill=(48, 50, 62), outline=(20, 20, 28))

def tower(X, Y):
    d.polygon([(X - 15 * SS, Y + 30 * SS), (X - 9 * SS, Y), (X + 9 * SS, Y), (X + 15 * SS, Y + 30 * SS)], fill=(208, 208, 200), outline=(80, 80, 76), width=SS)
    d.ellipse([X - 10 * SS, Y - 12 * SS, X + 10 * SS, Y + 4 * SS], fill=(230, 230, 232, 210))
    d.ellipse([X - 6 * SS, Y - 22 * SS, X + 8 * SS, Y - 8 * SS], fill=(236, 236, 240, 170))

def pylon(X, Y):
    d.line([X - 8 * SS, Y + 22 * SS, X, Y - 22 * SS], fill=(70, 70, 74), width=2 * SS)
    d.line([X + 8 * SS, Y + 22 * SS, X, Y - 22 * SS], fill=(70, 70, 74), width=2 * SS)
    d.line([X - 10 * SS, Y - 8 * SS, X + 10 * SS, Y - 8 * SS], fill=(70, 70, 74), width=2 * SS)
    d.line([X - 10 * SS, Y + 4 * SS, X + 10 * SS, Y + 4 * SS], fill=(70, 70, 74), width=SS)

def wreck(X, Y):
    c = random.choice([(150, 90, 60), (110, 110, 120), (130, 120, 70)])
    d.rectangle([X, Y, X + 14 * SS, Y + 7 * SS], fill=c, outline=(30, 30, 30), width=SS)
    d.line([X + 3 * SS, Y + 1 * SS, X + 11 * SS, Y + 6 * SS], fill=(30, 30, 30), width=SS)

def banner(X, Y):
    d.line([X, Y, X, Y - 26 * SS], fill=(60, 40, 30), width=2 * SS)
    d.polygon([(X, Y - 26 * SS), (X + 14 * SS, Y - 22 * SS), (X, Y - 14 * SS)], fill=(190, 40, 40), outline=(80, 14, 14))

def plane_wreck(X, Y):
    d.polygon([(X - 30 * SS, Y), (X + 22 * SS, Y - 4 * SS), (X + 30 * SS, Y), (X + 22 * SS, Y + 4 * SS)], fill=(214, 216, 220), outline=(70, 70, 76), width=SS)
    d.polygon([(X - 2 * SS, Y), (X - 14 * SS, Y - 20 * SS), (X + 4 * SS, Y - 2 * SS)], fill=(190, 192, 198), outline=(70, 70, 76))
    d.polygon([(X - 2 * SS, Y), (X - 10 * SS, Y + 18 * SS), (X + 4 * SS, Y + 2 * SS)], fill=(190, 192, 198), outline=(70, 70, 76))

# ---- mainland texture and regions ------------------------------------------------------------------
for _ in range(4500):
    x = random.randint(520, 985); y = random.randint(115, 595)
    X, Y = P(x, y)
    d.line([X, Y, X + random.randint(-3, 3) * SS, Y - 5 * SS], fill=(90, 130, 72, 110), width=SS)

REGIONS = {
    "district":    ([(525, 130), (715, 115), (752, 312), (650, 365), (520, 335)], (110, 118, 150, 130)),
    "residential": ([(718, 48), (860, 48), (860, 258), (752, 312), (715, 115)], (170, 130, 104, 110)),
    "field":       ([(752, 312), (860, 258), (990, 262), (990, 430), (770, 430), (725, 400)], (200, 190, 110, 100)),
    "start":       ([(740, 470), (850, 418), (930, 432), (920, 600), (780, 612), (745, 560)], (90, 190, 150, 105)),
    "wild":        ([(585, 462), (733, 462), (733, 597), (585, 597)], (50, 110, 60, 125)),
    "depot":       ([(545, 362), (645, 362), (645, 462), (545, 462)], (110, 122, 142, 150)),
}
ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
od = ImageDraw.Draw(ov)
for poly, col in REGIONS.values():
    od.polygon(pts(poly), fill=col)
img.paste(ov, (0, 0), ov)
d = ImageDraw.Draw(img, "RGBA")

# present-day ruins
for _ in range(16):
    x = random.uniform(545, 705); y = random.uniform(150, 330)
    if inside(REGIONS["district"][0], x, y):
        X, Y = P(x, y); ruin_block(X, Y, random.randint(14, 30) * SS, random.randint(18, 42) * SS)
scatter(REGIONS["residential"][0], 26, lambda X, Y: ruin_house(X, Y, 15))
scatter(REGIONS["residential"][0], 6, wreck)
scatter(REGIONS["start"][0], 7, lambda X, Y: tent(X, Y))
for cxy in ((820, 520), (880, 560)):
    campfire(*P(*cxy))
scatter(REGIONS["field"][0], 10, tree)
scatter(REGIONS["field"][0], 6, dead_tree)
scatter(REGIONS["field"][0], 5, wreck)
scatter(REGIONS["wild"][0], 40, tree)
scatter(REGIONS["wild"][0], 8, dead_tree)
# overgrown highway across the wilderness
hw = pts([(585, 505), (733, 520)])
d.line(hw, fill=(60, 62, 68), width=14 * SS)
d.line(hw, fill=(230, 210, 120), width=SS)
for k in range(4):
    wreck(*P(600 + k * 34, 502 + k * 3))
# depot rail yard
for k in range(4):
    y = 382 + k * 14
    d.line(pts([(552, y), (640, y)]), fill=(70, 60, 54), width=2 * SS)
for k in range(3):
    X, Y = P(556 + k * 30, 436)
    d.rectangle([X, Y, X + 24 * SS, Y + 12 * SS], fill=random.choice([(170, 80, 60), (70, 100, 150), (190, 160, 70)]), outline=(30, 30, 30), width=SS)

# Edo post town in the field (incursion)
X0, Y0 = P(872, 288); X1, Y1 = P(967, 386)
d.rectangle([X0, Y0, X1, Y1], fill=(212, 184, 140, 235), outline=(110, 64, 36), width=3 * SS)
for gx in range(3):
    for gy in range(3):
        edo_house(*P(882 + gx * 28, 312 + gy * 28), w=14)
torii(*P(920, 302), 0.8)

# new zones
Z = ZONES
scatter(Z["plant"]["poly"], 9, pylon)
scatter(Z["plant"]["poly"], 12, dead_tree)
tower(*P(640, -60)); tower(*P(700, -80)); tower(*P(760, -50))
ax0, ay0 = P(320, 470); ax1, ay1 = P(470, 490)
d.polygon([(ax0, ay0), (ax1, ay0 - 6 * SS), (ax1, ay1), (ax0, ay1 + 6 * SS)], fill=(56, 58, 64), outline=(30, 30, 34))
for k in range(8):
    xk = ax0 + (k + 0.5) * (ax1 - ax0) / 8
    d.line([xk, (ay0 + ay1) / 2, xk + 12 * SS, (ay0 + ay1) / 2], fill=(236, 236, 230), width=2 * SS)
for hx in (330, 380, 430):
    X, Y = P(hx, 520)
    d.polygon([(X, Y + 14 * SS), (X, Y), (X + 14 * SS, Y - 8 * SS), (X + 28 * SS, Y), (X + 28 * SS, Y + 14 * SS)], fill=(166, 170, 178), outline=(60, 64, 70), width=SS)
plane_wreck(*P(420, 450))
scatter(Z["badlands"]["poly"], 14, mesa)
scatter(Z["badlands"]["poly"], 26, dune)
scatter(Z["summit"]["poly"], 14, lambda X, Y: peak(X, Y, random.randint(14, 22) * SS, True, (130, 120, 150)), keep_out=[(1270, 90, 55)])
scatter(Z["summit"]["poly"], 10, lambda X, Y: crystal(X, Y, random.randint(8, 13) * SS))
scatter(Z["coast"]["poly"], 14, lantern)
scatter(Z["coast"]["poly"], 20, dune)
for tx, ty in ((985, 640), (1130, 700)):
    torii(*P(tx, ty), 1.1)
scatter(Z["bamboo"]["poly"], 34, bamboo)
for tx, ty in ((700, 700), (860, 650)):
    torii(*P(tx, ty), 0.9)
for tx, ty in ((760, 650), (835, 730)):
    tent(*P(tx, ty), col=(150, 70, 60))
scatter(Z["mountain"]["poly"], 14, lambda X, Y: peak(X, Y, random.randint(11, 17) * SS), keep_out=[(1030, 125, 62)])
castle(*P(1215, 415), 1.1)
for bx, by in ((1180, 450), (1250, 455), (1285, 400), (1160, 385)):
    banner(*P(bx, by))
    tent(*P(bx + 12, by + 10), col=(170, 60, 60))

# roads
ROADS = [
    [(840, 575), (850, 470), (800, 400), (740, 340), (640, 300), (590, 250)],
    [(850, 470), (920, 400), (990, 350), (1100, 380), (1180, 400)],
    [(990, 320), (1040, 220), (1030, 125)],
    [(1075, 150), (1180, 130), (1270, 90)],
    [(790, 150), (790, 48), (720, -60)],
    [(660, 420), (560, 410), (480, 385)],
    [(560, 430), (480, 470), (390, 500)],
    [(660, 520), (700, 640), (780, 690)],
    [(910, 520), (990, 600), (1060, 650)],
    [(700, 640), (600, 670), (500, 670)],
]
for road in ROADS:
    rp = pts(road)
    d.line(rp, fill=(60, 44, 30, 200), width=6 * SS, joint="curve")
    d.line(rp, fill=(214, 190, 136, 255), width=3 * SS, joint="curve")

# rifts: where old Japan bleeds into the ruined present
def rift(a, b, n=9):
    (x0, y0), (x1, y1) = P(*a), P(*b)
    seg = [(x0, y0)]
    for i in range(1, n):
        t = i / n
        nx, ny = -(y1 - y0), (x1 - x0)
        ln = math.hypot(nx, ny) or 1
        off = random.uniform(-9, 9) * SS
        seg.append((x0 + (x1 - x0) * t + nx / ln * off, y0 + (y1 - y0) * t + ny / ln * off))
    seg.append((x1, y1))
    d.line(seg, fill=RIFT + (60,), width=14 * SS, joint="curve")
    d.line(seg, fill=RIFT + (150,), width=7 * SS, joint="curve")
    d.line(seg, fill=(255, 235, 255, 255), width=2 * SS, joint="curve")
for a, b in [((992, 285), (992, 420)), ((922, 545), (922, 598)), ((905, 175), (1000, 255)),
             ((1100, 195), (1180, 232)), ((868, 262), (868, 395)), ((650, 615), (735, 603))]:
    rift(a, b)

def dashed(poly, col, width=3):
    p = pts(poly); p = p + [p[0]]
    for (x0, y0), (x1, y1) in zip(p, p[1:]):
        dist = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(dist / (14 * SS)))
        for i in range(0, n, 2):
            a, b = i / n, min(1, (i + 1) / n)
            d.line([x0 + (x1 - x0) * a, y0 + (y1 - y0) * a, x0 + (x1 - x0) * b, y0 + (y1 - y0) * b], fill=col, width=width * SS)
for z in Z.values():
    dashed(z["poly"], (255, 244, 214, 230))
for poly, col in REGIONS.values():
    p = pts(poly)
    d.line(p + [p[0]], fill=(col[0] // 2, col[1] // 2, col[2] // 2, 230), width=3 * SS, joint="curve")

# ---- landmarks -------------------------------------------------------------------------------------
cx, cy = P(1030, 125)
d.ellipse([cx - 52 * SS, cy - 52 * SS, cx + 52 * SS, cy + 52 * SS], fill=(214, 170, 100, 235), outline=(110, 74, 30), width=3 * SS)
d.rectangle([cx - 20 * SS, cy - 4 * SS, cx + 20 * SS, cy + 22 * SS], fill=(150, 40, 40), outline=(60, 20, 20), width=SS)
for k, wd in enumerate((34, 26, 18)):
    yy = cy - 4 * SS - k * 11 * SS
    d.polygon([(cx - wd * SS, yy), (cx, yy - 10 * SS), (cx + wd * SS, yy)], fill=(70, 60, 60), outline=(30, 24, 24))
torii(*P(1030, 190), 1.0)

fx, fy = P(470, 662)
R = 44 * SS
d.ellipse([fx - R, fy - R, fx + R, fy + R], outline=(110, 80, 150), width=4 * SS)
d.ellipse([fx - R * 0.55, fy - R * 0.55, fx + R * 0.55, fy + R * 0.55], outline=(140, 110, 180), width=2 * SS)
for k in range(8):
    a = k * math.pi / 4
    d.line([fx, fy, fx + R * math.cos(a), fy + R * math.sin(a)], fill=(110, 80, 150), width=2 * SS)
    gx, gy = fx + R * math.cos(a), fy + R * math.sin(a)
    d.ellipse([gx - 7 * SS, gy - 7 * SS, gx + 7 * SS, gy + 7 * SS], fill=(190, 150, 90), outline=(70, 44, 20))
d.polygon([(fx, fy), (fx - 20 * SS, fy + R + 20 * SS), (fx + 20 * SS, fy + R + 20 * SS)], outline=(80, 56, 110), width=3 * SS)
for tx, ty in ((540, 700), (590, 640), (430, 705)):
    X, Y = P(tx, ty)
    d.polygon([(X - 14 * SS, Y + 10 * SS), (X, Y - 14 * SS), (X + 14 * SS, Y + 10 * SS)], fill=(196, 110, 120), outline=(90, 40, 50))

sx, sy = P(610, 195)
d.polygon([(sx - 14 * SS, sy + 30 * SS), (sx - 5 * SS, sy - 50 * SS), (sx + 5 * SS, sy - 38 * SS), (sx + 14 * SS, sy + 30 * SS)], fill=(206, 210, 226), outline=(60, 60, 110))
d.line([sx - 5 * SS, sy - 50 * SS, sx + 1 * SS, sy - 44 * SS, sx + 5 * SS, sy - 38 * SS], fill=(60, 60, 110), width=2 * SS)

ux, uy = P(1270, 90)
d.polygon([(ux - 22 * SS, uy + 34 * SS), (ux - 8 * SS, uy - 46 * SS), (ux + 8 * SS, uy - 46 * SS), (ux + 22 * SS, uy + 34 * SS)], fill=(60, 52, 90), outline=(220, 200, 255), width=2 * SS)
d.polygon([(ux - 8 * SS, uy - 46 * SS), (ux, uy - 78 * SS), (ux + 8 * SS, uy - 46 * SS)], fill=(190, 160, 255), outline=(220, 200, 255))

def grace(x, y):
    X, Y = P(x, y)
    for r, a in ((16, 50), (11, 90)):
        d.ellipse([X - r * SS, Y - r * SS, X + r * SS, Y + r * SS], fill=(255, 214, 90, a))
    d.ellipse([X - 5 * SS, Y - 5 * SS, X + 5 * SS, Y + 5 * SS], fill=(255, 236, 140), outline=(140, 100, 20), width=SS)

def cave(x, y):
    X, Y = P(x, y)
    d.pieslice([X - 13 * SS, Y - 11 * SS, X + 13 * SS, Y + 15 * SS], 180, 360, fill=(40, 34, 40), outline=(230, 220, 200), width=2 * SS)
    d.rectangle([X - 13 * SS, Y + 2 * SS, X + 13 * SS, Y + 4 * SS], fill=(230, 220, 200))

def skull(x, y):
    X, Y = P(x, y); r = 10 * SS
    d.polygon([(X, Y - r), (X + r, Y), (X, Y + r), (X - r, Y)], fill=(120, 24, 24), outline=(255, 230, 200), width=2 * SS)

def boss(x, y, text):
    X, Y = P(x, y); r = 17 * SS
    d.ellipse([X - r, Y - r, X + r, Y + r], fill=(170, 30, 30), outline=(255, 230, 200), width=3 * SS)
    d.text((X, Y), "B", font=font(22, True), fill=(255, 240, 220), anchor="mm")
    d.text((X, Y + 32 * SS), text, font=font(21, True), fill=(255, 235, 200), anchor="mm", stroke_width=2 * SS, stroke_fill=(60, 10, 10))

for gx, gy in [(840, 560), (760, 500), (800, 340), (610, 320), (590, 250), (790, 150), (690, 410), (700, -40), (390, 495),
               (660, 540), (1060, 360), (1180, 410), (1030, 210), (1230, 110), (1060, 650), (780, 690), (560, 670)]:
    grace(gx, gy)
for cx_, cy_ in [(560, 200), (620, -100), (1290, 400), (1330, 60), (1010, 700), (720, 740), (335, 505)]:
    cave(cx_, cy_)
for sx_, sy_ in [(1250, 330), (1150, 540), (730, 670), (1220, 40), (870, 190), (790, -90), (310, 480)]:
    skull(sx_, sy_)

# gateway to Region 2 (a separate world): route and ship off the west edge
d.line(pts([(480, 385), (330, 385)]), fill=(245, 235, 200, 255), width=5 * SS)
hx, hy = P(330, 385)
d.polygon([(hx - 6 * SS, hy), (hx + 18 * SS, hy - 13 * SS), (hx + 18 * SS, hy + 13 * SS)], fill=(245, 235, 200, 255))
shx, shy = P(290, 350)
d.polygon([(shx - 28 * SS, shy), (shx + 28 * SS, shy), (shx + 19 * SS, shy + 14 * SS), (shx - 19 * SS, shy + 14 * SS)], fill=(90, 60, 40), outline=(30, 20, 10))
d.line([shx, shy, shx, shy - 32 * SS], fill=(30, 20, 10), width=2 * SS)
d.polygon([(shx, shy - 32 * SS), (shx + 21 * SS, shy - 9 * SS), (shx, shy - 9 * SS)], fill=(245, 240, 225), outline=(30, 20, 10))
rx, ry = P(395, 335)
d.text((rx, ry), "TO REGION 2", font=font(22, True), fill=(255, 250, 235), anchor="mm", stroke_width=2 * SS, stroke_fill=(30, 24, 20))
d.text((rx, ry + 24 * SS), "(a separate world)", font=font(16, False, True), fill=(255, 238, 200), anchor="mm", stroke_width=SS, stroke_fill=(30, 24, 20))

def label(x, y, text, size=30, level=None, color=MODERN):
    X, Y = P(x, y)
    d.text((X, Y), text, font=font(size, True), fill=color, anchor="mm", stroke_width=2 * SS, stroke_fill=(30, 24, 20))
    if level:
        d.text((X, Y + (size * 0.85) * SS), level, font=font(max(15, size * 0.55), False, True), fill=(255, 238, 200), anchor="mm", stroke_width=SS, stroke_fill=(30, 24, 20))

label(625, 250, "SHATTERED CITY", 30, "Lv 40-60  -  mid-high  -  the capital")
label(790, 165, "DEAD SUBURBS", 24, "Lv 15-25")
label(835, 350, "THE FIELD", 28, "Lv 5-15")
label(919, 272, "Edo post town", 19, "incursion", OLD)
label(850, 520, "REFUGE CAMP", 28, "Start zone  -  Lv 1-10")
label(659, 545, "OVERGROWN HIGHWAY", 21, "Lv 5-15")
label(595, 345, "FREIGHT DEPOT", 20, "Lv 15-25")
label(1000, 232, "SHRINE MOUNTAIN", 26, "Lv 90+  -  high-end", OLD)
label(1035, 178, "Clan house", 20, None, OLD)
label(1290, 220, "SKYFALL SUMMIT", 28, "Lv 100  -  the last rift")
label(1170, 500, "RIFT WASTES", 30, "Lv 70-90  -  Sengoku war camp", OLD)
label(1070, 700, "LANTERN COAST", 25, "Lv 15-30  -  Edo fishing port  -  low-mid", OLD)
label(780, 745, "BAMBOO VALLEY", 25, "Lv 20-30  -  ronin camps", OLD)
label(470, 713, "ABANDONED CARNIVAL", 21, "Lv 90")
label(700, -115, "DEAD POWER PLANT", 28, "Lv 60-75")
label(390, 555, "ABANDONED AIRFIELD", 21, "Lv 25-40")
boss(1030, 70, "Iridescent Requiem")
boss(570, 655, "Mandela (Hide Seto)")
boss(1275, 5, "???  (final)")

sx, sy = P(860, 585)
d.polygon([(sx, sy - 22 * SS), (sx + 8 * SS, sy - 4 * SS), (sx + 26 * SS, sy - 4 * SS), (sx + 12 * SS, sy + 7 * SS),
           (sx + 18 * SS, sy + 24 * SS), (sx, sy + 13 * SS), (sx - 18 * SS, sy + 24 * SS), (sx - 12 * SS, sy + 7 * SS),
           (sx - 26 * SS, sy - 4 * SS), (sx - 8 * SS, sy - 4 * SS)], fill=(255, 220, 90), outline=(120, 80, 10))

d.text((W * SS / 2, 62 * SS), "SOMEWHAT RPG", font=font(58, True), fill=(250, 238, 205), anchor="mm", stroke_width=3 * SS, stroke_fill=(20, 40, 60))
d.text((W * SS / 2, 108 * SS), "REGION 1  -  a ruined present, with old Japan breaking through", font=font(24, False, True), fill=(190, 215, 235), anchor="mm")

cx, cy = P(1380, 760)
r = 62 * SS
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(20, 50, 80, 180), outline=(240, 225, 190), width=3 * SS)
for ang, ln, wd in ((-90, r * 0.92, 9), (90, r * 0.6, 7), (0, r * 0.6, 7), (180, r * 0.6, 7)):
    a = math.radians(ang)
    tip = (cx + ln * math.cos(a), cy + ln * math.sin(a))
    l = (cx + wd * SS * math.cos(a + 1.57), cy + wd * SS * math.sin(a + 1.57))
    rr = (cx + wd * SS * math.cos(a - 1.57), cy + wd * SS * math.sin(a - 1.57))
    d.polygon([tip, l, rr], fill=(240, 225, 190) if ang == -90 else (150, 170, 190))
d.text((cx, cy - r - 18 * SS), "N", font=font(26, True), fill=(250, 238, 205), anchor="mm")

# legend
lx, ly = 60 * SS, (H - 150) * SS
d.rectangle([lx - 16 * SS, ly - 18 * SS, lx + 1500 * SS, ly + 128 * SS], fill=(20, 40, 60, 205), outline=(240, 225, 190), width=2 * SS)
ink = (245, 235, 210)
def ltext(x, y, t, col=ink):
    d.text((lx + x * SS, ly + y * SS), t, font=font(19), fill=col, anchor="lm")
d.rectangle([lx, ly, lx + 28 * SS, ly + 20 * SS], fill=(108, 142, 92), outline=(226, 212, 168), width=2 * SS)
ltext(40, 10, "Existing land (sketch)")
for k in range(0, 28, 8):
    d.line([lx + k * SS, ly + 52 * SS, lx + (k + 5) * SS, ly + 52 * SS], fill=(255, 244, 214, 230), width=3 * SS)
ltext(40, 52, "Planned zone")
d.line([lx, ly + 94 * SS, lx + 30 * SS, ly + 94 * SS], fill=(214, 190, 136), width=3 * SS)
ltext(40, 94, "Road")
gx_, gy_ = lx + 310 * SS, ly + 10 * SS
d.ellipse([gx_ - 14 * SS, gy_ - 14 * SS, gx_ + 14 * SS, gy_ + 14 * SS], fill=(255, 214, 90, 90))
d.ellipse([gx_ - 5 * SS, gy_ - 5 * SS, gx_ + 5 * SS, gy_ + 5 * SS], fill=(255, 236, 140), outline=(140, 100, 20), width=SS)
ltext(336, 10, "Fast-travel point (Spawn Keeper)")
cvx, cvy = lx + 310 * SS, ly + 52 * SS
d.pieslice([cvx - 13 * SS, cvy - 11 * SS, cvx + 13 * SS, cvy + 15 * SS], 180, 360, fill=(40, 34, 40), outline=(230, 220, 200), width=2 * SS)
ltext(336, 52, "Dungeon (metro, tunnel, cave)")
skx, sky = lx + 310 * SS, ly + 94 * SS
d.polygon([(skx, sky - 10 * SS), (skx + 10 * SS, sky), (skx, sky + 10 * SS), (skx - 10 * SS, sky)], fill=(120, 24, 24), outline=(255, 230, 200), width=2 * SS)
ltext(336, 94, "Field boss")
bx, by = lx + 740 * SS, ly + 10 * SS
d.ellipse([bx - 13 * SS, by - 13 * SS, bx + 13 * SS, by + 13 * SS], fill=(170, 30, 30), outline=(255, 230, 200), width=2 * SS)
ltext(762, 10, "Raid boss")
rf = [(lx + 727 * SS, ly + 54 * SS), (lx + 737 * SS, ly + 46 * SS), (lx + 745 * SS, ly + 58 * SS), (lx + 755 * SS, ly + 48 * SS)]
d.line(rf, fill=RIFT + (200,), width=5 * SS)
d.line(rf, fill=(255, 235, 255), width=SS)
ltext(762, 52, "Rift: old Japan breaking in")
ltext(740, 94, "Level bands and new zones are proposals")
ltext(1110, 10, "White names: present-day ruins", MODERN)
ltext(1110, 52, "Gold names: old-Japan incursion", OLD)
ltext(1110, 94, "Region 2 is a separate world")

d.rectangle([6 * SS, 6 * SS, (W - 6) * SS, (H - 6) * SS], outline=(240, 225, 190), width=4 * SS)

out = img.resize((W, H), Image.LANCZOS)
out.save("docs/world-map.png")
print("saved docs/world-map.png", out.size)
