#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Carte de l'histoire v2 — générée depuis les VRAIES cartes (cards_data.dart).
Panneau A : carte du voyage (gares, déblocages, arcs, fins, systèmes).
Panneau B : atlas de toutes les cartes par segment.
Sortie : docs/histoire_complet.png
"""
import re, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = open(f'{ROOT}/lib/data/cards_data.dart').read()
GS  = open(f'{ROOT}/lib/models/game_state.dart').read()

FP  = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FPB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def Fn(s, b=False): return ImageFont.truetype(FPB if b else FP, s)

# ---------------- parsing ----------------
def block(name, fn=False):
    pat = rf'{name}\(Set<String> f\) => \[' if fn else rf'{name}\s*=\s*(?:<StoryCard>)?\['
    m = re.search(pat, SRC)
    if not m: return ''
    i = m.end(); depth = 1; j = i
    while depth > 0 and j < len(SRC):
        if SRC[j] == '[': depth += 1
        elif SRC[j] == ']': depth -= 1
        j += 1
    return SRC[i:j-1]

def dartstr(s, i):
    # lit une chaîne dart ("..." ou '...') à partir de i (i = position du quote)
    q = s[i]; j = i+1; out = []
    while j < len(s):
        c = s[j]
        if c == '\\': out.append(s[j+1]); j += 2; continue
        if c == q: break
        out.append(c); j += 1
    return ''.join(out), j+1

STATL = {'soif':'S','faim':'F','bois':'B','moral':'M'}
def parse_fx(seg):
    fx = re.findall(r'Stat\.(\w+):\s*(-?\d+)', seg)
    return ' '.join(f"{STATL[k]}{'+' if int(v)>=0 else ''}{v}" for k,v in fx)

def parse_choice(seg):
    m = re.search(r'''_c\(\s*(['"])''', seg)
    if not m: return None
    label, j = dartstr(seg, m.end()-1)
    rest = seg[j:]
    fx = parse_fx(rest.split('result:')[0] if 'result:' in rest else rest)
    flags = re.findall(r"'((?:asset_|aLe|aLa|radio|cap|indice|soeur)\w*)'", rest.split('result:')[0])
    return (label, fx, flags)

def parse_cards(blk):
    cards = []
    # positions de départ de chaque carte
    starts = [(m.start(), 'sc', m.group(1)) for m in re.finditer(r"id:\s*'(\w+)'", blk)]
    starts += [(m.start(), 'f', m.group(1)) for m in re.finditer(r"_filler\(\s*'(\w+)'", blk)]
    starts += [(m.start(), 'e', m.group(1)) for m in re.finditer(r"_epreuve\(\s*'(\w+)'", blk)]
    starts.sort()
    for k,(pos, kind, cid) in enumerate(starts):
        end = starts[k+1][0] if k+1 < len(starts) else len(blk)
        seg = blk[pos:end]
        # texte de la carte : première longue chaîne
        text = ''
        tm = re.search(r'''text:\s*(['"])''', seg)
        if tm: text, _ = dartstr(seg, tm.end()-1)
        else:
            # _filler('id', "texte"  /  _epreuve('id', 'speaker', "texte"
            qs = [m.start() for m in re.finditer(r'''['"]''', seg)]
            idx = 2 if kind == 'f' else 4  # saute id (2 quotes) [+ speaker]
            if kind in ('f','e') and len(qs) > idx:
                text, _ = dartstr(seg, qs[idx])
        cm = [m.start() for m in re.finditer(r'_c\(', seg)]
        left = parse_choice(seg[cm[0]:cm[1] if len(cm)>1 else len(seg)]) if cm else None
        right = parse_choice(seg[cm[1]:]) if len(cm)>1 else None
        oneshot = 'oneshot: true' in seg
        req = None
        rm = re.search(r'requires:\s*\(f\)\s*=>\s*([^,\n]+)', seg)
        if rm:
            req = rm.group(1)
            req = re.sub(r"f\.contains\('(\w+)'\)", r'\1', req).replace('&&','&').replace('!','non ').strip()
            req = req.rstrip('),')
        cards.append(dict(id=cid, text=text, left=left, right=right, oneshot=oneshot, req=req))
    return cards

SEGS = {}
for n in range(1, 15):
    g = parse_cards(block(f'_gare{n}', fn=True))
    f = parse_cards(block(f'_fill{n}'))
    SEGS[n] = dict(gare=g, fill=f)
GLOB = {name: parse_cards(block(name)) for name in
        ['kSouvenirCards','kStateCards','kDogCards','kMomentCards']}

# déblocages par segment (asset_* posés dans les cartes du segment)
UNAMES = dict(re.findall(r"'(asset_\w+)':\s*'([^']+)'", GS))
SHORT = {'asset_bed':'PAILLASSE','asset_realbed':'LIT','asset_lamp':'LAMPE',
 'asset_filter':'FILTRE','asset_salon':'SALON NEUF','asset_atelier':'ATELIER RANGÉ',
 'asset_carillon':'CARILLON','asset_notebook':'CARNET','asset_fauteuil':'FAUTEUIL',
 'asset_stove':'POÊLE+CUISINE','asset_console':'CONSOLE','asset_shower':'DOUCHE',
 'asset_tournedisque':'TOURNE-DISQUE','asset_cellier':'CELLIER','asset_commode':'COMMODE',
 'asset_jeu':'TABLE DE JEU','asset_firstaid':'TROUSSE','asset_lantern':'LANTERNES',
 'asset_basket':'PANIER','asset_bath':'BAIN','asset_hydro':'HYDRO'}
def short(f):
    if f in SHORT: return SHORT[f]
    if f in UNAMES: return UNAMES[f].upper()[:12]
    return f.replace('asset_','').upper()

UNLOCKS = {}
ARCS = {}
for n, seg in SEGS.items():
    fl = set()
    for c in seg['gare'] + seg['fill']:
        for ch in (c['left'], c['right']):
            if ch: fl.update(ch[2])
    UNLOCKS[n] = sorted({f for f in fl if f.startswith('asset_')})
    for arc in ['aLeChien','aLaSoeur','aLaRadio','radio1','radio2','radio3']:
        if arc in fl and arc not in ARCS: ARCS[arc] = n

# ---------------- rendu ----------------
W = 2100
NAMES = ["Kogarashi\n(ville natale)","Kurogane\n(dépôt)","Karasuno\n(brouillard)",
 "Mayoidani\n(fantôme)","Tsukibashi\n(pont)","Yasuragi\n(camp)","Hoshikage\n(souvenir)",
 "Kiribe\n(entrée froid)","Shizuhara\n(blizzard)","Hidamari\n(serre)","Yukihara\n(barrage)",
 "Miharashi\n(guet)","Fubuki\n(col gelé)","Hokuto\n(refuge)"]
BEATS = ["fuite de la ville en flammes","1er arrêt : le chiot + nourrir la loco",
 "premiers pillards dans le brouillard","la radio à manivelle","RETROUVAILLES : la petite sœur",
 "camp-refuge, rumeur du Nord","souvenir d'enfance","le froid mord (drain bois/carte)",
 "tempête — la sœur fiévreuse","répit cosy (serre, bain)","barrage de pillards / radio",
 "le refuge en vue","sacrifice — la loco lâche","CLIMAX : les 5 fins"]

def zcol(g):
    if g <= 6: return (246,226,188)
    if g == 7: return (231,215,183)
    return (206,224,238)

PA_H = 1240
img = Image.new('RGB', (W, PA_H), (247,238,222))
d = ImageDraw.Draw(img)
d.text((W//2, 34), "TRAIN COSY — Carte de l'histoire (actualisée)", font=Fn(46, True), fill=(45,32,20), anchor='mm')
d.text((W//2, 82), "14 gares = cartes à CHOIX PUR (les combats ont été retirés) · inter-gares SEMI-ALÉATOIRES : la progression est toujours jouée, l'ambiance est tirée au sort", font=Fn(19), fill=(90,70,50), anchor='mm')
d.text((W//2, 108), "RYTHME : 1 carte = 1 crédit (5 max, +1 / 5 min réelles) · cinématique à chaque gare · ravitaillement d'arrivée +9 bois +5 eau +7 faim +4 moral · le bois brûle à CHAQUE carte", font=Fn(19), fill=(90,70,50), anchor='mm')

# zones
RAIL_Y = 420; X0 = 90; X1 = 1660
step = (X1-X0)/13
for g in range(1,15):
    x = X0 + (g-1)*step
    d.rectangle([x-step/2 if g>1 else 40, 140, x+step/2 if g<14 else X1+60, 860], fill=zcol(g))
d.text((X0+2.5*step, 160), "ZONE TEMPÉRÉE (g1-6)", font=Fn(24, True), fill=(150,110,40), anchor='mm')
d.text((X0+6*step, 160), "TRANSITION", font=Fn(22, True), fill=(120,95,55), anchor='mm')
d.text((X0+10.5*step, 160), "ZONE FROIDE (g8-14 · la loco boit plus)", font=Fn(24, True), fill=(70,110,150), anchor='mm')

# déblocages (chips au-dessus du rail)
d.text((44, 200), "DÉBLOQUÉS À CETTE GARE (objets réels posés par les cartes) :", font=Fn(17, True), fill=(110,80,40))
persos = {2:'CHIEN', 5:'SŒUR', 4:'RADIO'}
for g in range(1,15):
    x = X0 + (g-1)*step
    chips = [short(f) for f in UNLOCKS[g]]
    if g in persos: chips.insert(0, persos[g])
    yy = 226
    for c in chips[:7]:
        col = (196,90,60) if ('CHIEN' in c or 'SŒUR' in c or 'RADIO' in c) else (120,90,55)
        w = d.textlength(c, font=Fn(13, True)) + 12
        d.rounded_rectangle([x-w/2, yy, x+w/2, yy+20], 6, fill=(255,250,240), outline=col, width=2)
        d.text((x, yy+10), c, font=Fn(13, True), fill=col, anchor='mm')
        yy += 24
        if yy > RAIL_Y-40: break

# rail
d.line([(X0-30, RAIL_Y), (X1+30, RAIL_Y)], fill=(60,45,30), width=9)
for t in range(0, int(X1-X0)+60, 22):
    d.line([(X0-30+t, RAIL_Y-8), (X0-30+t, RAIL_Y+8)], fill=(60,45,30), width=3)
for g in range(1,15):
    x = X0 + (g-1)*step
    col = (232,185,107) if g == 1 else ((196,90,60) if g < 14 else (170,60,50))
    d.ellipse([x-26, RAIL_Y-26, x+26, RAIL_Y+26], fill=col, outline=(50,35,25), width=4)
    d.text((x, RAIL_Y), str(g), font=Fn(24, True), fill=(255,248,235), anchor='mm')
    nm = NAMES[g-1].split('\n')
    d.text((x, RAIL_Y-52), nm[0], font=Fn(19, True), fill=(50,38,26), anchor='mm')
    d.text((x, RAIL_Y-33), nm[1], font=Fn(14), fill=(90,72,52), anchor='mm')
    d.text((x, RAIL_Y+44 + (18 if g%2 else 0)), BEATS[g-1], font=Fn(13), fill=(80,62,44), anchor='mm')

# arcs
def arcbar(y, g0, label, col, extra=None):
    xa = X0 + (g0-1)*step; xb = X1
    d.rounded_rectangle([xa-24, y, xb+24, y+34], 17, fill=col, outline=(60,45,30), width=3)
    d.text((xa+8, y+17), label, font=Fn(17, True), fill=(255,250,240), anchor='lm')
    d.text((xa-24, y+46), '← entre ici', font=Fn(13), fill=col, anchor='lm')
    for (gg, lab) in (extra or []):
        xx = X0 + (gg-1)*step
        d.ellipse([xx-13, y+4, xx+13, y+30], fill=(255,250,240), outline=(60,45,30), width=2)
        d.text((xx, y+17), lab, font=Fn(12, True), fill=(60,45,30), anchor='mm')
arcbar(548, ARCS.get('aLeChien',2), 'CHIEN — ancre du moral (gagné à l’épreuve de Kurogane)', (150,105,70))
arcbar(612, ARCS.get('aLaSoeur',5), 'PETITE SŒUR — le cœur émotionnel (−faim/soif, +moral par carte)', (214,120,150))
arcbar(676, ARCS.get('aLaRadio',4), 'RADIO', (70,140,130),
       extra=[(ARCS.get('radio1',5),'R1'),(ARCS.get('radio2',7),'R2'),(ARCS.get('radio3',9),'R3')])
d.text((X0 + (ARCS.get('aLaRadio',4)-1)*step + 110, 676+50),
       "arc DÉLIBÉRÉ : seul « y croire » avance R1→R2→R3 · g12 : la voix dit ton PRÉNOM (indice) · R3 = la voix était maman (fin secrète)",
       font=Fn(14), fill=(60,110,100), anchor='lm')

# tenues & vie du wagon
d.rounded_rectangle([44, 762, X1+60, 850], 12, fill=(252,246,234), outline=(160,130,90), width=2)
d.text((60, 780), "ENTRE LES CARTES — la vie du wagon (Tamagotchi) :", font=Fn(16, True), fill=(110,80,40))
d.text((60, 806), "manger · boire · dormir · se laver (g10) · lire · danser · chien · duos avec la sœur · corvée de bûches à la loco (1 bûche = +10 bois) · souvenirs → CARNET DE VOYAGE",
       font=Fn(15), fill=(80,62,44))
d.text((60, 828), "TENUES (armoire, cellier) : Shen chemise / PYJAMA LAPIN (15 anims, chaleur +6) · sœur pyjama / PYJAMA DE LAINE (6 anims) · pyjamas assortis = carte-moment unique",
       font=Fn(15), fill=(80,62,44))

# fins (droite)
FINS = [
 ("FIN SECRÈTE — la voix retrouvée", "conditions de RÉUNIS + radio suivie jusqu'au bout (R3) : la voix était maman", (250,236,180),(180,140,40)),
 ("RÉUNIS (famille)", "sœur à bord + engagement parents + soin sœur ≥2 + moral ≥65", (214,236,196),(90,140,70)),
 ("ENSEMBLE", "arriver avec la sœur (sans le reste) = l'acceptation — la fin « cosy » dominante", (206,232,236),(70,130,140)),
 ("L'ABANDON", "moral à 0 (elle descend du train) OU arriver seule", (228,222,210),(130,115,95)),
 ("MORT", "soif, faim ou BOIS à 0 (le bois est la 1re cause : c'est le carburant)", (240,210,200),(170,80,60)),
]
fy = 200
d.text((1730, 176), "LES 5 FINS", font=Fn(26, True), fill=(60,45,30))
for (t, c, bg, bc) in FINS:
    d.rounded_rectangle([1720, fy, 2062, fy+92], 12, fill=bg, outline=bc, width=3)
    d.text((1736, fy+22), t, font=Fn(19, True), fill=(50,38,26), anchor='lm')
    # wrap desc
    words = c.split(); line=''; yy=fy+44
    for wd in words:
        if d.textlength(line+' '+wd, font=Fn(14)) > 310:
            d.text((1736, yy), line, font=Fn(14), fill=(70,56,40), anchor='lm'); yy+=19; line=wd
        else: line = (line+' '+wd).strip()
    d.text((1736, yy), line, font=Fn(14), fill=(70,56,40), anchor='lm')
    fy += 104
d.rounded_rectangle([1720, fy, 2062, fy+126], 12, fill=(252,246,234), outline=(160,130,90), width=2)
for k, t in enumerate(["ÉQUILIBRAGE (simu 4000 runs/profil) :","joueur négligent ~0% · casual ~12%","malin ~99% · aux petits soins ~99%","départ QUASI À ZÉRO (stats à 6/40)","morts : BOIS > moral > faim"]):
    d.text((1736, fy+18+k*21), t, font=Fn(15, k==0), fill=(90,70,50))
d.text((44, 890), "✓ SANS le mode debug : wagon abîmé et VIDE au départ, tout se GAGNE à sa gare (y compris le nettoyage des wagons : salon g2, atelier g3, cellier g6).", font=Fn(17, True), fill=(90,110,60))
d.text((44, 916), "Radio éteinte par défaut (tap = écoute 6 s) · tourne-disque = choix du disque (programme auto jour/nuit/froid) · crédits : l'attente se meuble dans le wagon.", font=Fn(15), fill=(80,62,44))
d.text((2056, 916), "Combats/mini-jeux : SUPPRIMÉS ✓ · « Le Vieux » : SUPPRIMÉ ✓", font=Fn(15, True), fill=(120,90,50), anchor='rm')

# stats cartes par segment
sy = 950
d.text((44, sy), "CARTES PAR SEGMENT (gare + inter-gares — la progression est TOUJOURS jouée, l'ambiance est tirée au sort dans la limite des crédits) :", font=Fn(16, True), fill=(110,80,40))
for g in range(1,15):
    x = X0 + (g-1)*step
    ng, nf = len(SEGS[g]['gare']), len(SEGS[g]['fill'])
    d.rounded_rectangle([x-42, sy+30, x+42, sy+74], 8, fill=(255,250,240), outline=(150,120,80), width=2)
    d.text((x, sy+42), f"{ng} gare", font=Fn(13, True), fill=(150,90,50), anchor='mm')
    d.text((x, sy+60), f"{nf} inter", font=Fn(13), fill=(90,72,52), anchor='mm')
nglob = {k: len(v) for k,v in GLOB.items()}
d.text((44, sy+92), f"+ cartes GLOBALES injectées partout : {nglob.get('kSouvenirCards',0)} souvenirs (carnet) · {nglob.get('kStateCards',0)} cartes d'état (épuisée/froid/démoralisée/choyée) · {nglob.get('kDogCards',0)} cartes chien · {nglob.get('kMomentCards',0)} moment (pyjamas assortis)", font=Fn(15), fill=(80,62,44))
d.text((44, sy+116), f"TOTAL : {sum(len(s['gare'])+len(s['fill']) for s in SEGS.values()) + sum(nglob.values())} cartes uniques · pertes ×1.20 · gains de moral ×0.6 · fins enrichies selon les flags (chien/soin/sœur)", font=Fn(15), fill=(80,62,44))

# ---------------- PANNEAU B : atlas ----------------
CW = 146; GAP = 4; LM = 24
def card_h(c):
    return 96
maxn = max(len(SEGS[g]['gare']) + len(SEGS[g]['fill']) for g in SEGS)
PB_H = 120 + maxn*(96+GAP) + 260
atlas = Image.new('RGB', (W, PB_H), (247,238,222))
da = ImageDraw.Draw(atlas)
da.text((W//2, 36), "TRAIN COSY — Toutes les cartes du jeu (parsées du code, à jour)", font=Fn(34, True), fill=(45,32,20), anchor='mm')
da.text((W//2, 72), "1 colonne = 1 gare · GARE en tête (choix pur) puis inter-gares · ◀ choix gauche / choix droit ▶ · M=moral S=soif F=faim B=bois · +NOM = débloque · 1x = unique · si… = conditionnelle", font=Fn(16), fill=(90,70,50), anchor='mm')

def draw_card(dr, x, y, c, is_gare):
    unlock = any(ch and any(f.startswith(('asset_','aLe','aLa','radio')) for f in ch[2]) for ch in (c['left'], c['right']))
    bg = (250,242,214) if is_gare else ((255,247,220) if unlock else (255,252,246))
    bc = (190,150,60) if is_gare else ((200,160,60) if unlock else (170,150,125))
    dr.rounded_rectangle([x, y, x+CW, y+96], 6, fill=bg, outline=bc, width=2)
    dr.text((x+5, y+9), c['id'][:16], font=Fn(10, True), fill=(140,95,40), anchor='lm')
    tags = []
    if c['oneshot']: tags.append('1x')
    if c['req']: tags.append('si…')
    if tags: dr.text((x+CW-5, y+9), ' '.join(tags), font=Fn(9), fill=(120,100,140), anchor='rm')
    # texte sur 2 lignes
    txt = c['text'][:110]
    line1 = txt[:34]; line2 = txt[34:68]
    dr.text((x+5, y+23), line1, font=Fn(9), fill=(70,56,40), anchor='lm')
    dr.text((x+5, y+34), line2 + ('…' if len(txt) > 68 else ''), font=Fn(9), fill=(70,56,40), anchor='lm')
    yy = y+48
    for mark, ch in (('◀', c['left']), ('▶', c['right'])):
        if not ch: continue
        lab, fx, flags = ch
        fl = ' '.join('+'+short(f) if f.startswith('asset_') else '+'+f for f in flags[:2])
        dr.text((x+5, yy), f"{mark} {lab[:26]}", font=Fn(9, True), fill=(60,48,34), anchor='lm')
        dr.text((x+12, yy+11), f"{fx} {fl}"[:34], font=Fn(9), fill=(150,90,50) if fl else (110,90,70), anchor='lm')
        yy += 24
for g in range(1,15):
    x = LM + (g-1)*(CW+GAP)
    da.rounded_rectangle([x, 100, x+CW, 130], 6, fill=zcol(g), outline=(120,95,55), width=2)
    da.text((x+CW/2, 115), f"{g} · {NAMES[g-1].splitlines()[0]}", font=Fn(12, True), fill=(60,45,30), anchor='mm')
    y = 136
    for c in SEGS[g]['gare']:
        draw_card(da, x, y, c, True); y += 96+GAP
    for c in SEGS[g]['fill']:
        draw_card(da, x, y, c, False); y += 96+GAP
# globales en bas (bande)
gy = 120 + maxn*(96+GAP) + 16
da.text((LM, gy), "CARTES GLOBALES (injectées dans tous les segments) :", font=Fn(16, True), fill=(110,80,40))
gx = LM; gyy = gy+28
for name, label in [('kSouvenirCards','SOUVENIRS (carnet)'),('kStateCards','ÉTATS'),('kDogCards','CHIEN'),('kMomentCards','MOMENTS')]:
    for c in GLOB[name]:
        if gx + CW > W-24: gx = LM; gyy += 100
        draw_card(da, gx, gyy, c, False)
        da.text((gx+CW/2, gyy-8), label, font=Fn(9, True), fill=(120,100,60), anchor='mm')
        gx += CW+GAP

out = Image.new('RGB', (W, PA_H + PB_H), (247,238,222))
out.paste(img, (0,0)); out.paste(atlas, (0, PA_H))
out.save(f'{ROOT}/docs/histoire_complet.png')
print('OK', out.size, 'cartes:', sum(len(s["gare"])+len(s["fill"]) for s in SEGS.values()), '+', sum(len(v) for v in GLOB.values()), 'globales')
