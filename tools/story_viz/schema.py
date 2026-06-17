#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont

W, H = 2000, 1240
BG = (243, 233, 214)
INK = (58, 46, 31)
INK2 = (120, 100, 75)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img, "RGBA")

FP = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FPB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def F(s, bold=False): return ImageFont.truetype(FPB if bold else FP, s)

def ctext(x, y, s, font, fill, anchor="mm"):
    d.text((x, y), s, font=font, fill=fill, anchor=anchor)

def tw(s, font): return d.textlength(s, font=font)

# ---- Titre ----
ctext(W//2, 46, "TRAIN COSY — Carte de l'histoire", F(46, True), INK)
ctext(W//2, 88, "14 gares (carte d'épreuve à chacune) · ~10 cartes d'ambiance FIXES entre chaque gare (toutes jouées) · objets & persos débloqués au fil de l'histoire",
      F(20), INK2)

# ---- Géométrie ----
N = 14
left_x, right_x = 150, 1500          # première / dernière gare
track_y = 560
xs = [left_x + i*(right_x-left_x)/(N-1) for i in range(N)]

names = ["Kogarashi","Kurogane","Karasuno","Mayoidani","Tsukibashi",
         "Yasuragi","Hoshikage","Kiribe","Shizuhara","Hidamari",
         "Yukihara","Miharashi","Fubuki","Hokuto"]
beats = ["ville natale en flammes","nourrir la loco","pillards/brouillard","mur des disparus / radio","RETROUVAILLES sœur",
         "camp louche","souvenir d'enfance","la sœur grelotte","sœur fiévreuse","répit cosy (serre)",
         "barrage pillards","refuge en vue","sacrifice loco","CLIMAX / fins"]
epreuve_gares = set(range(0,14))  # TOUTES les gares ont une carte d'épreuve (menace résolue par un choix)

# ---- Bandes de zones ----
def band(x0, x1, color, label):
    d.rectangle([x0, 120, x1, H-150], fill=color)
    ctext((x0+x1)/2, 140, label, F(22, True), (255,255,255,230))

b_wt = (xs[5]+xs[6])/2     # fin tempéré (gare 6) / début transition (gare 7)
b_tc = (xs[6]+xs[7])/2     # fin transition (gare 7) / début froid (gare 8)
band(90, b_wt, (232,178,96,90), "ZONE TEMPÉRÉE")
band(b_wt, b_tc, (175,150,120,90), "TRANSITION")
band(b_tc, 1560, (150,185,215,110), "ZONE FROIDE  (loco boit +,  −bois/carte)")

# ---- Voie ferrée ----
d.line([(left_x-20, track_y), (right_x+20, track_y)], fill=(77,59,40), width=10)
for i in range(N-1):
    x0, x1 = xs[i], xs[i+1]
    k = 6
    for j in range(k):
        tx = x0 + (x1-x0)*(j+0.5)/k
        d.line([(tx, track_y-16),(tx, track_y+16)], fill=(120,95,65), width=3)

# ---- Gares ----
for i,x in enumerate(xs):
    r = 26
    fill = (226,90,70) if i in epreuve_gares else (232,185,107)
    d.ellipse([x-r, track_y-r, x+r, track_y+r], fill=fill, outline=INK, width=3)
    ctext(x, track_y, str(i+1), F(24, True), (40,30,20))
    # nom au-dessus / situation en-dessous, EN ALTERNANCE (2 hauteurs) pour
    # éviter le chevauchement horizontal des libellés.
    ny = track_y-48 if i%2==0 else track_y-78
    by = track_y+48 if i%2==0 else track_y+78
    d.line([(x, track_y-r-2),(x, ny+10)], fill=(150,130,100), width=1)
    d.line([(x, track_y+r+2),(x, by-10)], fill=(150,130,100), width=1)
    ctext(x, ny, names[i], F(16, True), INK)
    ctext(x, by, beats[i], F(13), INK2)

ctext((xs[2]), 200, "● chaque gare : une CARTE D'ÉPREUVE résout la menace (pillards, barrage…) par un choix", F(15, True), (200,70,55))

# ---- Objets débloqués, PAR GARE (empilés au-dessus de la station) ----
OBJ_COL={'LIT':(201,155,106),'GAMELLE':(176,122,74),'LAMPE':(228,180,90),
 'CARNET':(150,120,175),'FILTRE EAU':(111,168,199),
 'ARMOIRE':(150,112,82),'POÊLE':(200,95,70),'TROUSSE':(208,120,120),
 'HYDRO':(123,174,107),'BAIN':(95,160,200),'DOUCHE':(92,150,182),
 'LANTERNES':(214,170,90)}
# Placement RÉEL (flags asset_* dans cards_data) : lit+gamelle g1, lampe g2,
# carnet g3, filtre g4, armoire+cellier g6, poêle+trousse g8,
# hydro+bain+douche+lanternes g10. (TABLE retirée ; ARMOIRE = dans le cellier.)
gare_objs={0:['LIT','GAMELLE'],1:['LAMPE'],2:['CARNET'],3:['FILTRE EAU'],
 5:['ARMOIRE'],7:['POÊLE','TROUSSE'],9:['HYDRO','BAIN','DOUCHE','LANTERNES']}
ctext(150, 244, "OBJETS DÉBLOQUÉS (apparaissent dans le wagon à cette gare)", F(17, True), INK)
for gi, objs in gare_objs.items():
    x = xs[gi]
    d.line([(x, 266),(x, track_y-66)], fill=(150,130,100), width=2)
    yy = 268
    for lab in objs:
        col = OBJ_COL.get(lab,(180,150,110))
        wq = max(84, tw(lab, F(14,True))+18)
        d.rounded_rectangle([x-wq/2, yy, x+wq/2, yy+30], radius=9, fill=col, outline=INK, width=2)
        ctext(x, yy+15, lab, F(14, True), (255,255,255))
        yy += 35

# ---- Couloirs de personnages (en-dessous) ----
def lane(gi_start, gi_end, label, color, y, frags=None):
    x0 = xs[gi_start]-32
    x1 = xs[gi_end]+32
    d.rounded_rectangle([x0, y-18, x1, y+18], radius=18, fill=color+(235,), outline=INK, width=2)
    # libellé calé à gauche, à l'intérieur de la barre
    ctext(x0+16, y, label, F(16, True), (255,255,255), anchor="lm")
    # repère "entre dans l'histoire ici"
    ctext(xs[gi_start], y+34, "← entre ici", F(12, True), color, anchor="mm")
    if frags:
        for gi, tag in frags:
            fx = xs[gi]
            d.ellipse([fx-12, y-12, fx+12, y+12], fill=(255,255,255), outline=INK, width=2)
            ctext(fx, y, tag, F(12, True), INK)

ctext(150, 690, "PERSONNAGES & ARCS", F(18, True), INK)
lane(0, 13, "CHIEN", (176,122,74), 745)
lane(4, 13, "PETITE SŒUR", (226,155,176), 810)
# Radio : objet gare 4, puis fragments radio1(g5) radio2(g7-8) radio3(g9-10) -> voix = maman
lane(3, 13, "RADIO", (90,160,160), 875, frags=[(4,"R1"),(6,"R2"),(8,"R3")])
ctext(xs[6], 912, "chaîne radio fragile : objet→R1→R2→R3 = la voix de maman → fin secrète", F(13), INK2, anchor="mm")

# ---- Fins (à droite) ----
ex = 1600
ctext(ex+150, 250, "LES 5 FINS", F(20, True), INK)
ends = [
 ("FIN SECRÈTE — La voix retrouvée", (232,194,74), "sœur + soin≥2 + moral≥65 + RADIO jusqu'au bout (R3)"),
 ("RÉUNIS (famille)", (123,174,107), "sœur + soin≥2 + moral≥65"),
 ("TOUTES LES DEUX", (90,160,160), "sœur + moral≥30"),
 ("L'ABANDON", (154,140,120), "moral tombe à 0 / conditions non remplies"),
 ("MORT", (194,90,74), "soif / faim / bois tombe à 0"),
]
ey = 300
for title, col, cond in ends:
    d.line([(xs[13]+26, track_y),(ex-10, ey+30)], fill=col+(160,), width=3)
    d.rounded_rectangle([ex, ey, ex+360, ey+96], radius=14, fill=col+(60,), outline=col, width=3)
    ctext(ex+18, ey+26, title, F(18, True), INK, anchor="lm")
    # wrap condition
    words = cond.split(" ")
    line1, line2 = "", ""
    for wd in words:
        if tw((line1+" "+wd).strip(), F(14)) < 330: line1 = (line1+" "+wd).strip()
        else: line2 = (line2+" "+wd).strip()
    ctext(ex+18, ey+54, line1, F(14), INK, anchor="lm")
    if line2: ctext(ex+18, ey+76, line2, F(14), INK, anchor="lm")
    ey += 112

# ---- Légende bas ----
ly = H-120
ctext(110, ly, "✓ SANS le mode debug, le jeu suit EXACTEMENT ce plan : wagon vide au départ, tout apparaît à sa gare.", F(16, True), (90,120,70), anchor="lm")
ctext(110, ly+30, "LIT = débloqué dès la GARE 1 (carte G1, les 2 choix). ARMOIRE = dans le 2e wagon (cellier), débloqué gare 6. TABLE retirée.", F(15), INK, anchor="lm")
ctext(110, ly+58, "Le mode debug (🐞) affiche tout d'un coup + permet de jouer les cartes librement (Passer / sauter de gare).", F(14), INK2, anchor="lm")
ctext(W-110, ly+58, "Le Vieux + l'enfant : SUPPRIMÉS ✓", F(16, True), (123,140,90), anchor="rm")

img.save("/home/user/survival/docs/histoire_schema.png")
print("OK", img.size)
