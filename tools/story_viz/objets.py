#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
FP="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FPB="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def Fn(s,b=False): return ImageFont.truetype(FPB if b else FP,s)
W,H=1600,1120
img=Image.new("RGB",(W,H),(243,233,214)); d=ImageDraw.Draw(img,"RGBA")
INK=(58,46,31); INK2=(110,92,70)
def ct(x,y,s,f,fill,a="lm"): d.text((x,y),s,font=f,fill=fill,anchor=a)

ct(W//2,46,"TRAIN COSY — Objets & personnages débloqués par l'histoire",Fn(32,True),INK,"mm")
ct(W//2,84,"SANS le mode debug, le jeu suit EXACTEMENT ce plan : chaque élément apparaît à sa gare (avant, le wagon est vide).",Fn(17),INK2,"mm")

def row(x,y,name,where,key,note=""):
    col=(168,208,138)
    d.rounded_rectangle([x,y,x+700,y+58],radius=10,fill=col+(70,),outline=col,width=2)
    d.ellipse([x+14,y+16,x+42,y+44],fill=col,outline=INK,width=2)
    ct(x+28,y+30,"✓",Fn(18,True),(255,255,255),"mm")
    ct(x+56,y+18,name,Fn(19,True),INK,"lm")
    ct(x+56,y+41,key,Fn(12),INK2,"lm")
    ct(x+700-16,y+18,where,Fn(17,True),INK,"rm")
    if note: ct(x+700-16,y+41,note,Fn(12),(180,90,40),"rm")

LX=40; y=126
ct(LX,y,"PERSONNAGES",Fn(22,True),INK,"lm"); y+=42
row(LX,y,"Chien","Gare 1","aLeChien","reste g1 (chiot pendant la fuite)"); y+=68
row(LX,y,"Petite sœur","Gare 5","aLaSoeur"); y+=68
row(LX,y,"Radio (objet)","Segment 4→5","aLaRadio"); y+=68
row(LX,y,"Radio R1 / R2 / R3","Seg 5→6 / 7→8 / 9→10","radio1/2/3"); y+=84
ct(LX,y,"OBJETS DU WAGON",Fn(22,True),INK,"lm"); y+=42
row(LX,y,"Lit","Gare 1","asset_bed"); y+=68
row(LX,y,"Gamelle (chien)","Gare 1","asset_bowl"); y+=68
row(LX,y,"Lampe","Gare 2","asset_lamp"); y+=68
row(LX,y,"Table","Gare 2","asset_table"); y+=68

RX=860; y=126
ct(RX,y,"OBJETS DU WAGON (suite)",Fn(22,True),INK,"lm"); y+=42
row(RX,y,"Carnet / livre","Gare 3","asset_notebook"); y+=68
row(RX,y,"Filtre à eau","Gare 4","asset_filter"); y+=68
row(RX,y,"Commode","Gare 6","asset_commode"); y+=68
row(RX,y,"Poêle (chauffage)","Gare 8","asset_stove"); y+=68
row(RX,y,"Trousse de secours","Gare 8","asset_firstaid"); y+=68
row(RX,y,"Hydroponie (serre)","Gare 10","asset_hydro"); y+=84
ct(RX,y,"CELLIER (2e wagon)",Fn(22,True),INK,"lm"); y+=42
row(RX,y,"Bain","Gare 10","asset_bath"); y+=68
row(RX,y,"Douche","Gare 10","asset_shower"); y+=68

ny=H-130
d.rounded_rectangle([40,ny,W-40,H-30],radius=12,fill=(255,255,255,160),outline=(150,125,95),width=2)
ct(60,ny+28,"✓ Tout est câblé : en mode JEU, le wagon démarre VIDE et se remplit gare après gare comme ci-dessus.",Fn(17,True),INK,"lm")
ct(60,ny+60,"Pour déplacer un objet : dis « poêle → gare 6 » et je rebranche le flag. (Le chien peut aussi passer en gare 2-3 si tu confirmes.)",Fn(15),INK2,"lm")

img.save("/home/user/survival/docs/objets_placement.png")
print("OK",img.size)
