#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
FP="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FPB="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def F(s,b=False): return ImageFont.truetype(FPB if b else FP,s)
W,H=1700,1180
img=Image.new("RGB",(W,H),(243,233,214)); d=ImageDraw.Draw(img,"RGBA")
INK=(58,46,31); INK2=(110,92,70)
def ct(x,y,s,f,fill,a="mm"): d.text((x,y),s,font=f,fill=fill,anchor=a)
def wrap(x,y,s,f,fill,maxw,a="mm",lh=22):
    words=s.split(); line=""; lines=[]
    for w in words:
        t=(line+" "+w).strip()
        if d.textlength(t,font=f)<=maxw: line=t
        else: lines.append(line); line=w
    if line: lines.append(line)
    for i,l in enumerate(lines): ct(x,y+i*lh,l,f,fill,a)

ct(W//2,46,"TRAIN COSY — La boucle de jeu",F(40,True),INK)
ct(W//2,86,"Structure cible : ouverture → train vide + tuto → [ cartes → cinématique → gare/combat → s'occuper de Shen ] × 14 gares",F(17),INK2)

# ---- Démarrage (linéaire, en haut) ----
def box(x,y,w,h,title,sub,col):
    d.rounded_rectangle([x,y,x+w,y+h],radius=12,fill=col+(70,),outline=col,width=3)
    ct(x+w/2,y+24,title,F(17,True),INK)
    if sub: wrap(x+w/2,y+50,sub,F(13),INK2,w-24,lh=18)
sy=120; bw=300; bh=92; gap=40; sx=60
box(sx,sy,bw,bh,"🎬  Cinématique d'ouverture".replace("🎬",""),"La nuit de la fuite : explosions, famille séparée, Shen monte dans le train",(150,110,170))
d.line([(sx+bw,sy+bh/2),(sx+bw+gap,sy+bh/2)],fill=INK,width=3)
box(sx+bw+gap,sy,bw,bh,"Train VIDE + abîmé","On apparaît seule dans le wagon nu, stats au plus bas, il fait froid",(150,110,70))
d.line([(sx+2*(bw+gap),sy+bh/2),(sx+2*(bw+gap)+gap,sy+bh/2)],fill=INK,width=3)
box(sx+2*(bw+gap),sy,bw,bh,"Bulles de TUTO","Résument ce qui vient de se passer + s'affichent à chaque 1re utilisation d'un truc",(120,150,150))
d.line([(sx+3*(bw+gap),sy+bh/2),(sx+3*(bw+gap)+gap,sy+bh/2)],fill=INK,width=3)
box(sx+3*(bw+gap),sy,bw-40,bh,"↓ LA BOUCLE","Répétée à chaque gare jusqu'au nord",(200,140,30))

# ---- Le CYCLE (4 phases) au centre ----
cx,cy=W//2,640; R=230
phases=[
 ("1 · ~10 CARTES","Reigns : choix qui font avancer l'histoire et DÉBLOQUENT des objets (filtre, hydro…). On comprend parfois mieux le passé.",(232,185,107),-90),
 ("2 · CINÉMATIQUE","Le train entre en gare et s'arrête. Mise en scène de l'évènement à venir.",(150,110,170),0),
 ("3 · GARE = COMBAT","Un évènement qui fait avancer l'histoire OU fait gagner un élément clé, joué pendant un COMBAT (ex. sauver le chiot).",(226,90,70),90),
 ("4 · S'OCCUPER DE SHEN","Entre les phases : comme les Sims / un Tamagotchi — manger, boire, dormir, se laver, jouer avec le chien…",(123,174,107),180),
]
import math
pts=[]
for i,(t,s,col,ang) in enumerate(phases):
    a=math.radians(ang)
    px=cx+R*math.cos(a); py=cy+R*math.sin(a)
    pts.append((px,py,col))
# flèches du cycle (entre les points, sens horaire)
for i in range(4):
    x0,y0,_=pts[i]; x1,y1,_=pts[(i+1)%4]
    d.line([(x0,y0),(x1,y1)],fill=(150,120,90),width=4)
# noeuds
for i,(t,s,col,ang) in enumerate(phases):
    px,py,_=pts[i]
    bw2,bh2=300,150
    d.rounded_rectangle([px-bw2/2,py-bh2/2,px+bw2/2,py+bh2/2],radius=14,fill=col+(80,),outline=col,width=3)
    ct(px,py-bh2/2+22,t,F(16,True),INK)
    wrap(px,py-bh2/2+50,s,F(12),INK2,bw2-22,lh=17)
ct(cx,cy-18,"BOUCLE",F(22,True),INK)
ct(cx,cy+12,"d'une gare",F(16),INK2)
# flèche circulaire indicative
ct(cx,cy+44,"↻",F(40,True),(200,140,30))

# ---- Exemple gare 1 (bas) ----
ey=1010
d.rounded_rectangle([60,ey,W-60,H-30],radius=12,fill=(255,255,255,160),outline=(150,125,95),width=2)
ct(80,ey+26,"EXEMPLE — Gare 1 :",F(17,True),INK,"lm")
wrap(80,ey+58,"Le train est entre la VILLE NATALE (départ, où le jeu se terminera) et la 1re gare. Les ~10 cartes font gagner le FILTRE À EAU + la TOUR HYDRO. À ce stade : train abîmé, filtre+hydro acquis, il fait froid, stats quasi à zéro. → Cinématique : entrée en gare, un CHIOT sur le quai, on sort, on se fait attaquer → si on joue bien, on SAUVE le chiot.",F(13),INK2,W-180,a="lm",lh=19)

img.save("/home/user/survival/docs/boucle_jeu.png")
print("OK",img.size)
