#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
from PIL import Image, ImageDraw, ImageFont
F = json.load(open('/tmp/fillers.json'))

FP="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FPB="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def Fn(s,b=False): return ImageFont.truetype(FPB if b else FP,s)

def zonecol(g):
    if g<=6: return (246,226,188)
    if g==7: return (230,214,182)
    return (206,224,238)
def zonename(g):
    if g<=6: return "TEMPÉRÉ"
    if g==7: return "TRANSITION"
    return "FROID"

GARES={
1:[("G1","Ville en flammes","Regarder","M-6","Fermer la porte","M+3","gain"),
   ("G1b","Chiot sous un banc","Le recueillir","M+15 +CHIEN","Refuser","M-5","gain"),
   ("G1c","Séparation (souvenir)","Jurer de les retrouver","M+10","Se préparer au pire","M-8 F+4",None)],
2:[("G2","Nourrir la loco","Déchiffrer le manuel","B+18 F-4","À l'instinct","B+6 M-3",None),
   ("G2win","COMBAT BON : dépôt sécurisé","Plein de bois","B+12","Chercher vivres","F+8 S+5","bon"),
   ("G2lose","COMBAT RATÉ : réserve pillée","Sauver le reste","B-6","Repartir furieuse","M-4 F-3","rate")],
3:[("G3","Pillards/brouillard","Passer en fantôme","B-6 M-4","Accélérer","B-10 M+3",None),
   ("G3b","Foulard d'enfant","Risquer pour l'attraper","F-8 M+12 +indice","Ne pas risquer","M-8",None),
   ("G3win","COMBAT BON : wagon intact","Souffler","M+8","Fouiller butin","F+6 B+4","bon"),
   ("G3lose","COMBAT RATÉ : wagon abîmé","Colmater","B-6 M-3","Repartir","F-5","rate")],
4:[("G4","Mur des disparus","Y croire, foncer","M+14 B-8 +indice","Rester méfiante","M-4","gain"),
   ("G4win","COMBAT BON : village sûr","Fouiller maisons","F+8 S+6","Chercher messages","M+8","bon"),
   ("G4lose","COMBAT RATÉ : embuscade","Décrocher vite","F-6 M-3","Récupérer un peu","S-5 B-4","rate")],
5:[("G5","LA SŒUR, vivante !","Courir la serrer","M+40 +SŒUR","(idem)","M+40 +SŒUR","gain"),
   ("G5b","Parents au nord","Lui promettre","M+12 +cap","Rester prudente","M+4 +cap",None),
   ("G5win","COMBAT BON : sœur indemne","La serrer encore","M+10","Filer vite","B+4 M+5","bon"),
   ("G5lose","COMBAT RATÉ : elle a vu","La consoler","M-3 F-4 +SOIN","L'endurcir","M+4","rate")],
6:[("G6","Camp louche","Troquer et partir","F+12 S+8 M-6","Ne pas s'attarder","M+6 F-5",None),
   ("G6win","COMBAT BON : respect du camp","Négocier d'égal","F+10 S+6 M+4","Garde payée","F+12 B+4","bon"),
   ("G6lose","COMBAT RATÉ : prix durcis","Payer fort","F-8 M-4","Partir sans rien","M-5","rate")],
7:[("G7","Souvenir d'enfance","Raconter","M+16 B-5","Garder le cap","M+4",None),
   ("G7win","COMBAT BON : halte sûre","Moment à la sœur","M+12","Fouiller la halte","F+6 B+4","bon"),
   ("G7lose","COMBAT RATÉ : charme rompu","Rassurer","M-3","Repartir aussitôt","B-5","rate")],
8:[("G8","La sœur grelotte","Donner ton manteau","M+14 S-6 +SOIN","Pousser le feu","B-16 M+6",None),
   ("G8win","COMBAT BON : wagon hermétique","Calfeutrer","B+6 M+4","Veiller la sœur","M+8 +SOIN","bon"),
   ("G8lose","COMBAT RATÉ : porte cédée","Tout brûler","B-10 +SOIN","Serrer les dents","S-6 M-4","rate")],
9:[("G9","Sœur fiévreuse","La veiller","F-10 M+12 +SOIN","Braver la tempête","S-12 M+8 +SOIN",None),
   ("G9win","COMBAT BON : sœur reposée","Soigner sans relâche","M+10 +SOIN","Récup. matériel","F+8 B+6","bon"),
   ("G9lose","COMBAT RATÉ : fièvre remonte","Tout donner","F-10 M+6 +SOIN","Foncer à l'abri","B-8 M-4","rate")],
10:[("G10","Serre cosy","Vrai repos","F+20 S+16 M+18","Plein, repartir","F+12 S+10 B+12","gain"),
   ("G10win","COMBAT BON : serre défendue","Récolte massive","F+14 S+10","Profiter","M+12","bon"),
   ("G10lose","COMBAT RATÉ : serre saccagée","Sauver plants","F+6 M-3","Repartir dégoûtée","M-5","rate")],
11:[("G11","Barrage pillards","Foncer","B-18 M-6","Négocier","F-16 S-10 M+4",None),
   ("G11win","COMBAT BON : déroute","Rafler butin","F+10 B+8","Passer vite","M+8","bon"),
   ("G11lose","COMBAT RATÉ : prix fort","Panser","F-8 M-4","Fuir","B-8 M+3","rate")],
12:[("G12","Vue sur le refuge","Jurer qu'ils sont là","M+18","Tempérer l'espoir","M+6",None),
   ("G12win","COMBAT BON : poste tenu","Repérer le chemin","M+10 B+4","Vivres du poste","F+8 S+6","bon"),
   ("G12lose","COMBAT RATÉ : délogée","Rassurer la sœur","M-3","Pousser au nord","B-6","rate")],
13:[("G13","Loco sans bois","Brûler le mobilier","B+28 M-8","Pousser ensemble","F-14 S-10 M+10",None),
   ("G13win","COMBAT BON : charognards tenus","Récup. leur bois","B+12","Reprendre souffle","M+8","bon"),
   ("G13lose","COMBAT RATÉ : bois perdu","Tout sacrifier","F-10 M-4","Brûler l'impossible","B-8 M+4","rate")],
14:[("G14win","COMBAT BON : refuge triomphal","Entrer tête haute","M+12","Offrir le butin","M+8 F+4","bon"),
   ("G14lose","COMBAT RATÉ : entrée cabossée","S'effondrer","M+4","Tenir pour elle","M-3","rate"),
   ("G14","Refuge — arrivée","Chercher vos parents","→ FIN","(idem)","→ FIN",None)],
}
NAMES=["Gare natale","Dépôt de fret","Halte 47","Village fantôme","Pont/fleuve","Camp-refuge",
"Halte 12","Zone froide","Plaine enneigée","Oasis serre","Halte 31","Tour de guet","Col gelé","Refuge nord"]

GAINF={'aLeChien':'CHIEN','aLaSoeur':'SŒUR','aLaRadio':'RADIO','radio1':'R1','radio2':'R2',
'radio3':'R3','asset_bed':'LIT','asset_filter':'FILTRE','asset_hydro':'HYDRO','indiceSoeur':'indice',
'capParents':'cap','soeurProtegee':'SOIN'}
CONDF={'aLeChien':'si CHIEN','aLaSoeur':'si SŒUR','aLaRadio':'si RADIO','radio1':'si R1','radio2':'si R2'}

def col_cards(g):
    cards=[(c[0],c[1],c[2],c[3],c[4],c[5],c[6],None) for c in GARES[g]]
    for fl in F.get(str(g),[]):
        gain = any(x in GAINF for x in fl['left'][2]+fl['right'][2])
        tag='gain' if gain else None
        cond=" ".join(CONDF.get(r,r) for r in fl['requires']) if fl['requires'] else None
        lL,lfx=fl['left'][0],fl['left'][1]; rL,rfx=fl['right'][0],fl['right'][1]
        g2=[GAINF[x] for x in fl['left'][2] if x in GAINF]
        if g2: lfx=(lfx+" +"+"+".join(g2)).strip()
        g2=[GAINF[x] for x in fl['right'][2] if x in GAINF]
        if g2: rfx=(rfx+" +"+"+".join(g2)).strip()
        cards.append((fl['id'],fl['text'],lL,lfx,rL,rfx,tag,cond))
    return cards

COLW=300; GAP=10; PADX=30; TOPY=222
maxn=max(len(col_cards(g)) for g in range(1,15))
CELLH=96; HEADH=64
W=PADX*2+14*COLW+13*GAP
H=TOPY+HEADH+maxn*(CELLH+8)+170
img=Image.new("RGB",(W,H),(243,233,214)); d=ImageDraw.Draw(img,"RGBA")
def ct(x,y,s,f,fill,a="lm"): d.text((x,y),s,font=f,fill=fill,anchor=a)
def cut(s,f,maxw):
    if d.textlength(s,font=f)<=maxw: return s
    while s and d.textlength(s+"…",font=f)>maxw: s=s[:-1]
    return s+"…"
INK=(58,46,31); INK2=(110,92,70)

ct(W//2,44,"TRAIN COSY — Toutes les cartes du jeu",Fn(40,True),INK,"mm")
ct(W//2,84,"1 colonne = 1 gare · cartes dans l'ordre de jeu (FIXE) · chaque carte : ◀ choix gauche  /  choix droite ▶",Fn(18),INK2,"mm")

# ===== LÉGENDE (2 rangées encadrées) =====
lx,lw = PADX, W-2*PADX
# rangée 1 : les 4 jauges
ly=108; lh=42
d.rounded_rectangle([lx,ly,lx+lw,ly+lh],radius=10,fill=(255,255,255,170),outline=(150,125,95),width=2)
cy=ly+lh//2; x=lx+18
ct(x,cy,"LÉGENDE — les 4 jauges :",Fn(17,True),INK,"lm"); x+=d.textlength("LÉGENDE — les 4 jauges :",font=Fn(17,True))+26
for ab,full,col in [("M","Moral / espoir",(214,120,150)),("S","Soif → eau",(95,160,200)),
                    ("F","Faim → nourriture",(210,150,80)),("B","Bois → carburant loco",(150,110,70))]:
    d.ellipse([x,cy-13,x+26,cy+13],fill=col,outline=(60,45,30),width=1)
    ct(x+13,cy,ab,Fn(14,True),(255,255,255),"mm"); x+=33
    ct(x,cy,"= "+full,Fn(16),INK,"lm"); x+=d.textlength("= "+full,font=Fn(16))+30
ct(x,cy,"  →  ex.  M+15 = +15 moral,   B-8 = −8 bois",Fn(15),INK2,"lm")
# rangée 2 : badges
ly2=ly+lh+8; lh2=42
d.rounded_rectangle([lx,ly2,lx+lw,ly2+lh2],radius=10,fill=(255,255,255,170),outline=(150,125,95),width=2)
cy2=ly2+lh2//2; x=lx+18
def swatch(x,fill,bord,bw,label):
    d.rounded_rectangle([x,cy2-13,x+28,cy2+13],radius=6,fill=fill,outline=bord,width=bw)
    ct(x+38,cy2,label,Fn(16),INK,"lm")
    return x+38+d.textlength(label,font=Fn(16))+32
x=swatch(x,(255,255,255,0),(200,140,30),3,"★ bord doré = débloque objet/perso (+CHIEN +SŒUR +LIT +FILTRE +HYDRO +RADIO…)")
x=swatch(x,(225,242,225),(70,150,70),3,"vert = si COMBAT réussi")
x=swatch(x,(245,225,222),(194,90,74),3,"rouge = si COMBAT raté")
d.rounded_rectangle([x,cy2-13,x+52,cy2+13],radius=8,fill=(120,150,150,230))
ct(x+10,cy2,"si X",Fn(13),(255,255,255),"lm"); x+=64
ct(x,cy2,"= carte conditionnelle (apparaît seulement si le flag X est présent)",Fn(16),INK,"lm")

# ===== Colonnes =====
for gi in range(14):
    g=gi+1; cx=PADX+gi*(COLW+GAP); zc=zonecol(g)
    d.rounded_rectangle([cx,TOPY,cx+COLW,TOPY+HEADH],radius=10,fill=(zc[0]-12,zc[1]-12,zc[2]-12),outline=(120,95,65),width=2)
    d.ellipse([cx+8,TOPY+14,cx+44,TOPY+50],fill=(232,185,107),outline=INK,width=2)
    ct(cx+26,TOPY+32,str(g),Fn(20,True),(40,30,20),"mm")
    ct(cx+54,TOPY+22,cut(NAMES[gi],Fn(15,True),COLW-64),Fn(15,True),INK,"lm")
    ct(cx+54,TOPY+44,zonename(g),Fn(12),INK2,"lm")
    y=TOPY+HEADH+8
    for (cid,situ,lL,lfx,rL,rfx,tag,cond) in col_cards(g):
        bg=(255,255,255,150); bord=(150,125,95); pw=1
        if tag=='gain': bord=(200,140,30); pw=3
        elif tag=='bon': bord=(70,150,70); pw=3; bg=(225,242,225,160)
        elif tag=='rate': bord=(194,90,74); pw=3; bg=(245,225,222,160)
        d.rounded_rectangle([cx,y,cx+COLW,y+CELLH],radius=9,fill=bg,outline=bord,width=pw)
        ct(cx+10,y+15,cid,Fn(13,True),INK,"lm")
        if cond:
            bw=d.textlength(cond,font=Fn(11))+12
            d.rounded_rectangle([cx+COLW-bw-8,y+6,cx+COLW-8,y+24],radius=8,fill=(120,150,150,220))
            ct(cx+COLW-bw-2,y+15,cond,Fn(11),(255,255,255),"lm")
        ct(cx+10,y+36,cut(situ,Fn(12),COLW-20),Fn(12),INK2,"lm")
        ct(cx+10,y+58,cut("◀ "+lL,Fn(11,True),COLW-20),Fn(11,True),(70,55,35),"lm")
        ct(cx+24,y+74,cut(lfx,Fn(11),COLW-30),Fn(11),(150,90,40),"lm")
        ct(cx+COLW-10,y+58,cut(rL+" ▶",Fn(11,True),COLW-20),Fn(11,True),(70,55,35),"rm")
        ct(cx+COLW-24,y+74,cut(rfx,Fn(11),COLW-30),Fn(11),(150,90,40),"rm")
        y+=CELLH+8

# ===== Fins =====
fy=H-150
ct(PADX,fy-8,"LES 5 FINS (résolution à la gare 14)  —  « SOIN » = nb de gestes de protection de la sœur",Fn(20,True),INK,"lm")
ends=[("FIN SECRÈTE","sœur + SOIN≥2 + moral≥65 + R3",(240,216,115)),
("RÉUNIS (famille)","sœur + SOIN≥2 + moral≥65",(168,208,138)),
("TOUTES LES DEUX","sœur + moral≥30",(154,208,206)),
("L'ABANDON","moral 0 / sinon",(201,187,166)),
("MORT","soif/faim/bois → 0",(224,149,138))]
ex=PADX
for t,c,col in ends:
    bw=(W-2*PADX-4*12)/5
    d.rounded_rectangle([ex,fy+10,ex+bw,fy+96],radius=12,fill=col+(90,),outline=(58,46,31),width=2)
    ct(ex+16,fy+36,t,Fn(17,True),INK,"lm")
    ct(ex+16,fy+66,c,Fn(13),INK2,"lm")
    ex+=bw+12

img.save("/home/user/survival/docs/histoire_complet.png")
print("OK",img.size)
