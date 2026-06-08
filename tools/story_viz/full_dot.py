#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
F = json.load(open('/tmp/fillers.json'))

def esc(s):
    return (s.replace('\\','\\\\').replace('|','/').replace('{','(').replace('}',')')
             .replace('<','‹').replace('>','›').replace('"',"'"))
def short(s,n=46):
    s=s.strip()
    return s if len(s)<=n else s[:n-1]+'…'

GOLD="#C8922A"
def zonecol(g): return "#F6E2BC" if g<=6 else ("#E2D2B0" if g==7 else "#CFE0EE")
out=[]; w=out.append
w('digraph histoire {')
w('  rankdir=TB; bgcolor="#F3E9D6"; nodesep=0.25; ranksep=0.4;')
w('  fontname="DejaVu Sans"; labelloc="t"; fontsize=30;')
w('  label="TRAIN COSY — Toutes les cartes (gares + cartes d\'ambiance FIXES + choix + branches + fins)";')
w('  node [fontname="DejaVu Sans", fontsize=10];')
w('  edge [fontname="DejaVu Sans", fontsize=9, color="#5A4632", arrowsize=0.7];')

def rec(nid, title, situ, lL, lfx, rL, rfx, fill, gain=False, cond=None, dashed=False):
    if cond: title += f"  «si {cond}»"
    if gain: title += "   ★"
    left=f"◀ {short(lL,30)}\\n{lfx}"; right=f"{short(rL,30)} ▶\\n{rfx}"
    lab="{%s|%s|{%s|%s}}"%(esc(title),esc(short(situ)),esc(left),esc(right))
    style="filled,rounded" + (",dashed" if dashed else "")
    bord=GOLD if gain else "#7A5C3A"; pw=3 if gain else 1
    w(f'  {nid} [shape=record, style="{style}", fillcolor="{fill}", color="{bord}", penwidth={pw}, label="{lab}"];')

def diamond(nid,g): w(f'  {nid} [shape=diamond,style=filled,fillcolor="#E25A46",fontcolor=white,fontsize=11,label="COMBAT gare {g}\\nselon le score"];')
def arrow(a,b,lbl=None,color=None,style=None):
    at=[]
    if lbl: at.append(f'label="{esc(lbl)}"')
    if color: at.append(f'color="{color}"')
    if style: at.append(f'style={style}')
    w(f'  {a} -> {b} [{",".join(at)}];')

GAINFLAGS={'aLeChien','aLaSoeur','aLaRadio','radio1','radio2','radio3','asset_bed','asset_filter','asset_hydro'}
def filler_chain(prev_nodes, seg_n, gare_for_color):
    """Emet les fillers du segment seg_n en chaîne, renvoie le dernier node."""
    fillers=F.get(str(seg_n),[])
    col=zonecol(gare_for_color)
    last=None
    # cluster visuel du segment
    w(f'  subgraph cluster_seg{seg_n} {{ label="cartes d\'ambiance  gare {seg_n}→{seg_n+1}  ({len(fillers)} cartes, toutes jouées"; style="rounded,dashed"; color="#B0A082"; fontsize=12;')
    prev=None
    for fl in fillers:
        nid=f"f_{fl['id']}"
        gain=any(g in GAINFLAGS for g in (fl['left'][2]+fl['right'][2]))
        cond=" + ".join(fl['requires']) if fl['requires'] else None
        rec(nid, fl['id'], fl['text'], fl['left'][0], fl['left'][1],
            fl['right'][0], fl['right'][1], col, gain=gain, cond=cond, dashed=bool(cond))
        if prev: arrow(prev, nid)
        prev=nid
    w('  }')
    if fillers:
        first=f"f_{fillers[0]['id']}"
        for p in prev_nodes: arrow(p, first)
        return [prev]
    return prev_nodes

# ===== Gares (données manuelles, fidèles) =====
def gare_card(nid,g,ids,situ,lL,lfx,rL,rfx,gain=False):
    rec(nid,f"G{g} · {ids}",situ,lL,lfx,rL,rfx,zonecol(g),gain=gain)

gare_card("G1",1,"G1","Ville natale en flammes","Regarder jusqu'au bout","M-6","Fermer la porte","M+3",gain=True)
gare_card("G1b",1,"G1b","Chiot sous un banc","Le recueillir","M+15 CHIEN","Refuser","M-5",gain=True)
gare_card("G1c",1,"G1c","Souvenir de la séparation","Te jurer de les retrouver","M+10","Te préparer au pire","M-8 F+4")
arrow("G1","G1b"); arrow("G1b","G1c")
last=filler_chain(["G1c"],1,1)

gare_card("G2",2,"G2","Nourrir la loco au bois","Déchiffrer le manuel","B+18 F-4","À l'instinct","B+6 M-3")
for p in last: arrow(p,"G2")
last=filler_chain(["G2"],2,2)

gare_card("G3",3,"G3","Pillards dans le brouillard","Passer en fantôme","B-6 M-4","Accélérer","B-10 M+3")
gare_card("G3b",3,"G3b","Foulard d'enfant (sœur ?)","Risquer pour l'attraper","F-8 M+12 indice","Ne pas risquer","M-8")
diamond("C3",3)
gare_card("G3win",3,"G3win (bon combat)","Wagon intact","Souffler","M+8","Fouiller le butin","F+6 B+4")
gare_card("G3lose",3,"G3lose (combat raté)","Wagon abîmé","Colmater","B-6 M-3","Repartir","F-5")
for p in last: arrow(p,"G3")
arrow("G3","G3b"); arrow("G3b","C3"); arrow("C3","G3win","bon","#3C8C3C"); arrow("C3","G3lose","raté","#C25A4A")
last=filler_chain(["G3win","G3lose"],3,3)

gare_card("G4",4,"G4","Mur des disparus + mot d'enfant","Y croire, foncer","M+14 B-8 indice","Rester méfiante","M-4",gain=True)
for p in last: arrow(p,"G4")
last=filler_chain(["G4"],4,4)

gare_card("G5",5,"G5","La petite sœur, vivante !","Courir la serrer","M+40 SŒUR","(idem)","M+40 SŒUR",gain=True)
gare_card("G5b",5,"G5b","Parents partis au nord","Lui promettre","M+12 cap","Rester prudente","M+4 cap")
diamond("C5",5)
gare_card("G5win",5,"G5win (bon combat)","Sœur indemne","La serrer encore","M+10","Filer vite","B+4 M+5")
gare_card("G5lose",5,"G5lose (combat raté)","Elle a vu l'horreur","La consoler","M-3 F-4 SOIN","L'endurcir","M+4")
for p in last: arrow(p,"G5")
arrow("G5","G5b"); arrow("G5b","C5"); arrow("C5","G5win","bon","#3C8C3C"); arrow("C5","G5lose","raté","#C25A4A")
last=filler_chain(["G5win","G5lose"],5,6)

gare_card("G6",6,"G6","Camp louche","Troquer et partir","F+12 S+8 M-6","Ne pas s'attarder","M+6 F-5")
for p in last: arrow(p,"G6")
last=filler_chain(["G6"],6,6)

gare_card("G7",7,"G7","Souvenir d'enfance","Raconter le souvenir","M+16 B-5","Garder le cap","M+4")
for p in last: arrow(p,"G7")
last=filler_chain(["G7"],7,7)

gare_card("G8",8,"G8","La sœur grelotte","Lui donner ton manteau","M+14 S-6 SOIN","Pousser le feu","B-16 M+6")
for p in last: arrow(p,"G8")
last=filler_chain(["G8"],8,8)

gare_card("G9",9,"G9","Sœur fiévreuse, blizzard","La veiller","F-10 M+12 SOIN","Braver la tempête","S-12 M+8 SOIN")
for p in last: arrow(p,"G9")
last=filler_chain(["G9"],9,9)

gare_card("G10",10,"G10","Serre cosy, répit","Vrai repos","F+20 S+16 M+18","Plein et repartir","F+12 S+10 B+12",gain=True)
for p in last: arrow(p,"G10")
last=filler_chain(["G10"],10,10)

gare_card("G11",11,"G11","Barrage de pillards","Foncer","B-18 M-6","Négocier","F-16 S-10 M+4")
diamond("C11",11)
gare_card("G11win",11,"G11win (bon combat)","Pillards en déroute","Rafler le butin","F+10 B+8","Passer vite","M+8")
gare_card("G11lose",11,"G11lose (combat raté)","Assaut au prix fort","Panser","F-8 M-4","Fuir","B-8 M+3")
for p in last: arrow(p,"G11")
arrow("G11","C11"); arrow("C11","G11win","bon","#3C8C3C"); arrow("C11","G11lose","raté","#C25A4A")
last=filler_chain(["G11win","G11lose"],11,11)

gare_card("G12",12,"G12","Vue sur le refuge nord","Jurer qu'ils sont là","M+18","Tempérer l'espoir","M+6")
for p in last: arrow(p,"G12")
last=filler_chain(["G12"],12,12)

gare_card("G13",13,"G13","Loco à court de bois","Brûler le mobilier","B+28 M-8","Descendre pousser","F-14 S-10 M+10")
for p in last: arrow(p,"G13")
w('  n1314 [shape=plaintext,fontcolor="#8A7A5E",fontsize=11,label="(gares 13 & 14 : aucune carte d\'ambiance)"];')
arrow("G13","n1314",style="invis")

gare_card("G14",14,"G14","Refuge du nord — arrivée","Chercher vos parents","→ fin","(idem)","→ fin")
arrow("G13","G14")

def ending(nid,t,c,col): w(f'  {nid} [shape=box,style="filled,rounded",fillcolor="{col}",color="#3A2E1F",penwidth=2,fontsize=12,label="{esc(t)}\\n{esc(c)}"];')
ending("Es","FIN SECRÈTE — La voix retrouvée","sœur + SOIN≥2 + moral≥65 + R3","#F0D873")
ending("Ef","RÉUNIS (famille)","sœur + SOIN≥2 + moral≥65","#A8D08A")
ending("Ee","TOUTES LES DEUX","sœur + moral≥30","#9AD0CE")
ending("Ea","L'ABANDON","moral à 0 / conditions non remplies","#C9BBA6")
ending("Em","MORT","soif/faim/bois à 0 (à tout moment)","#E0958A")
arrow("G14","Es","R3 suivie","#C8922A"); arrow("G14","Ef","sœur soignée")
arrow("G14","Ee","sœur, moral moyen"); arrow("G14","Ea","moral au plus bas")
w('  G14 -> Em [label="jauge à 0",style=dashed,color="#C25A4A"];')
w('}')
open('/tmp/full.dot','w').write("\n".join(out))
print("ok")
