#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
FP="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FPB="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def Fn(s,b=False): return ImageFont.truetype(FPB if b else FP,s)
W,H=1600,1180
img=Image.new("RGB",(W,H),(243,233,214)); d=ImageDraw.Draw(img,"RGBA")
INK=(58,46,31); INK2=(110,92,70)
def ct(x,y,s,f,fill,a="lm"): d.text((x,y),s,font=f,fill=fill,anchor=a)

ct(W//2,46,"TRAIN COSY — Objets & personnages : où ils se débloquent",Fn(34,True),INK,"mm")
ct(W//2,84,"Chaque élément n'apparaît dans le jeu QUE lorsqu'une carte pose son flag asset_… (sinon wagon vide).",Fn(17),INK2,"mm")

def row(x,y,name,where,key,placed,note=""):
    col=(168,208,138) if placed else (240,196,120)
    d.rounded_rectangle([x,y,x+700,y+62],radius=10,fill=col+(70,),outline=col,width=2)
    # pastille statut
    d.ellipse([x+14,y+18,x+44,y+48],fill=col,outline=INK,width=2)
    ct(x+29,y+33,"✓" if placed else "?",Fn(20,True),(255,255,255),"mm")
    ct(x+60,y+20,name,Fn(20,True),INK,"lm")
    ct(x+60,y+44,key,Fn(13),INK2,"lm")
    ct(x+700-16,y+20,where,Fn(17,True),INK,"rm")
    if note: ct(x+700-16,y+44,note,Fn(13),(180,90,40),"rm")

# ---- Colonne gauche : PERSOS + PLACÉS ----
LX=40; y=130
ct(LX,y,"PERSONNAGES",Fn(22,True),INK,"lm"); y+=44
row(LX,y,"Chien","Gare 1","aLeChien",True,"tu veux → gare 2-3"); y+=74
row(LX,y,"Petite sœur","Gare 5","aLaSoeur",True); y+=74
row(LX,y,"Radio (objet)","Segment 4→5","aLaRadio",True); y+=74
row(LX,y,"Radio R1 / R2 / R3","Seg 5→6 / 7→8 / 9→10","radio1/2/3",True); y+=90

ct(LX,y,"OBJETS DÉJÀ PLACÉS",Fn(22,True),INK,"lm"); y+=44
row(LX,y,"Lit","Gare 1","asset_bed",True); y+=74
row(LX,y,"Filtre à eau","Gare 4","asset_filter",True); y+=74
row(LX,y,"Hydroponie (serre)","Gare 10","asset_hydro",True); y+=74

# ---- Colonne droite : À PLACER ----
RX=860; y=130
ct(RX,y,"OBJETS À PLACER  (aucune gare pour l'instant)",Fn(22,True),(180,90,40),"lm"); y+=44
toplace=[
 ("Lampe","asset_lamp"),
 ("Poêle (chauffage)","asset_stove"),
 ("Table","asset_table"),
 ("Carnet / livre","asset_notebook"),
 ("Trousse de secours","asset_firstaid"),
 ("Commode","asset_commode"),
 ("Gamelle (chien)","asset_bowl"),
 ("Bain  (cellier)","asset_bath"),
 ("Douche  (cellier)","asset_shower"),
]
for name,key in toplace:
    row(RX,y,name,"À PLACER",key,False); y+=74

# ---- bas : note ----
ny=H-150
d.rounded_rectangle([40,ny,W-40,H-30],radius=12,fill=(255,255,255,160),outline=(150,125,95),width=2)
ct(60,ny+30,"Dis-moi à quelle gare débloquer chaque objet 'À PLACER' (ex. « lampe → gare 2, poêle → gare 8, bain+douche → gare 10 »).",Fn(17),INK,"lm")
ct(60,ny+62,"Je propose si tu veux : Lampe→g2 · Table→g2 · Gamelle→g2 (avec le chien) · Carnet→g3 · Poêle→g8 (froid) · Trousse→g8 · Commode→g6 · Bain+Douche→g10 (l'oasis).",Fn(16),INK2,"lm")
ct(60,ny+92,"⚠️ Bain & douche sont dans le CELLIER (2e wagon) et ne sont pas encore gérés par flag — il faut aussi les brancher côté code.",Fn(15),(180,90,40),"lm")

img.save("/home/user/survival/docs/objets_placement.png")
print("OK",img.size)
