#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Génère un organigramme Graphviz de toute l'histoire (gares, cartes, choix,
# branches combat, pools de fillers, fins).

def esc(s):
    return (s.replace('\\','\\\\').replace('|','/').replace('{','(').replace('}',')')
             .replace('<','‹').replace('>','›').replace('"',"'"))

ZONE = {  # 1-based gare -> couleur de fond (tempéré / transition / froid)
}
def zonecol(g):
    if g <= 6: return "#F6E2BC"       # tempéré
    if g == 7: return "#E2D2B0"       # transition
    return "#CFE0EE"                  # froid

GOLD = "#C8922A"
out = []
def w(s): out.append(s)

w('digraph histoire {')
w('  rankdir=TB; bgcolor="#F3E9D6"; nodesep=0.35; ranksep=0.55;')
w('  fontname="DejaVu Sans"; labelloc="t"; fontsize=26;')
w('  label="TRAIN COSY — Organigramme de l\'histoire  (cartes · choix · branches · fins)";')
w('  node [fontname="DejaVu Sans", fontsize=11];')
w('  edge [fontname="DejaVu Sans", fontsize=10, color="#5A4632"];')

# ---- carte : record {titre | situation | {◀ gauche | droite ▶}} ----
def card(nid, gare, ids, situ, lL, lfx, rL, rfx, gain=None):
    title = f"GARE {gare} · {ids}"
    if gain: title += f"   [+{gain}]"
    left = f"◀ {lL}\\n{lfx}"
    right = f"{rL} ▶\\n{rfx}"
    lab = "{%s|%s|{%s|%s}}" % (esc(title), esc(situ), esc(left), esc(right))
    bord = GOLD if gain else "#7A5C3A"
    pw = 3 if gain else 1
    w(f'  {nid} [shape=record, style="filled,rounded", fillcolor="{zonecol(gare)}", color="{bord}", penwidth={pw}, label="{lab}"];')

def pool(nid, seg, n, gains):
    txt = f"Cartes d'ambiance {seg}\\n~{n} cartes · 4 tirées au hasard"
    if gains:
        txt += "\\n" + "\\n".join("• "+g for g in gains)
    w(f'  {nid} [shape=note, style=filled, fillcolor="#EDE3CF", color="#9A8A6E", fontsize=10, label="{esc(txt)}"];')

def diamond(nid, gare):
    w(f'  {nid} [shape=diamond, style=filled, fillcolor="#E25A46", fontcolor=white, label="{esc("COMBAT gare %d"%gare)}\\nselon le score"];')

def arrow(a, b, lbl=None, color=None, style=None):
    attrs=[]
    if lbl: attrs.append(f'label="{esc(lbl)}"')
    if color: attrs.append(f'color="{color}"')
    if style: attrs.append(f'style={style}')
    w(f'  {a} -> {b} [{",".join(attrs)}];')

# ============ GARE 1 ============
card("G1",1,"G1","Ville natale en flammes vue du wagon","Regarder jusqu'au bout","M-6","Fermer la porte","M+3",gain="LIT")
card("G1b",1,"G1b","Chiot tremblant sous un banc","Le recueillir","M+15 · +CHIEN","Refuser (1 bouche de +)","M-5",gain="CHIEN")
card("G1c",1,"G1c","Souvenir de la séparation","Te jurer de les retrouver","M+10","Te préparer au pire","M-8 F+4")
arrow("G1","G1b"); arrow("G1b","G1c")

pool("P1","1→2",10,["F1_chien_nuit (si CHIEN)"])
arrow("G1c","P1")

# ============ GARE 2 ============
card("G2",2,"G2","Apprendre à nourrir la loco","Déchiffrer le manuel","B+18 F-4","À l'instinct","B+6 M-3")
arrow("P1","G2")
pool("P2","2→3",10,[])
arrow("G2","P2")

# ============ GARE 3 (combat) ============
card("G3",3,"G3","Pillards dans le brouillard","Passer en fantôme","B-6 M-4","Accélérer pour les semer","B-10 M+3")
card("G3b",3,"G3b","Foulard d'enfant (= la sœur ?)","Risquer pour l'attraper","F-8 M+12 · indice","Ne pas risquer","M-8")
diamond("C3",3)
card("G3win",3,"G3win","si BON combat : wagon intact","Souffler","M+8","Fouiller leur butin","F+6 B+4")
card("G3lose",3,"G3lose","si combat RATÉ : wagon abîmé","Colmater","B-6 M-3","Repartir","F-5")
arrow("P2","G3"); arrow("G3","G3b"); arrow("G3b","C3")
arrow("C3","G3win","bon score","#3C8C3C"); arrow("C3","G3lose","raté","#C25A4A")
pool("P3","3→4",10,["F3_chien_garde (si CHIEN)"])
arrow("G3win","P3"); arrow("G3lose","P3")

# ============ GARE 4 ============
card("G4",4,"G4","Mur des disparus + mot d'enfant 'JE VAIS AU NORD'","Y croire, foncer","M+14 B-8 · indice","Rester méfiante","M-4",gain="FILTRE EAU")
arrow("P3","G4")
pool("P4","4→5",11,["F4_radio_trouvee → +RADIO (objet)","F4_dessin_soeur"])
arrow("G4","P4")

# ============ GARE 5 (combat + RETROUVAILLES) ============
card("G5",5,"G5","La petite sœur, vivante, barre la route","Courir la serrer","M+40 · +SŒUR","(idem)","M+40 · +SŒUR",gain="SŒUR")
card("G5b",5,"G5b","Elle révèle : parents au nord","Lui promettre","M+12 · cap","Rester prudente","M+4 · cap")
diamond("C5",5)
card("G5win",5,"G5win","si BON combat : sœur indemne","La serrer encore","M+10","Filer vite","B+4 M+5")
card("G5lose",5,"G5lose","si combat RATÉ : elle a vu l'horreur","La consoler","M-3 F-4 · SOIN","L'endurcir","M+4")
arrow("P4","G5"); arrow("G5","G5b"); arrow("G5b","C5")
arrow("C5","G5win","bon score","#3C8C3C"); arrow("C5","G5lose","raté","#C25A4A")
pool("P5","5→6",10,["F5_radio_premier → R1 (si RADIO)","fillers sœur (billes, cabane)"])
arrow("G5win","P5"); arrow("G5lose","P5")

# ============ GARE 6 ============
card("G6",6,"G6","Camp louche, on lorgne la sœur","Troquer vite et partir","F+12 S+8 M-6","Ne pas s'attarder","M+6 F-5")
arrow("P5","G6")
pool("P6","6→7",10,["fillers sœur"])
arrow("G6","P6")

# ============ GARE 7 (transition) ============
card("G7",7,"G7","Halte d'enfance, la sœur sourit","Lui raconter le souvenir","M+16 B-5","Garder le cap","M+4")
arrow("P6","G7")
pool("P7","7→8",11,["F7_radio_voix → R2 (si R1)"])
arrow("G7","P7")

# ============ GARE 8 (froid) ============
card("G8",8,"G8","La sœur grelotte, pas de manteau","Lui donner le tien","M+14 S-6 · SOIN","Pousser le feu","B-16 M+6")
arrow("P7","G8")
pool("P8","8→9",10,["F8_soeur_cache → SOIN","F8_chien_froid (si CHIEN)"])
arrow("G8","P8")

# ============ GARE 9 ============
card("G9",9,"G9","Sœur fiévreuse, blizzard","La veiller","F-10 M+12 · SOIN","Braver la tempête (remèdes)","S-12 M+8 · SOIN")
arrow("P8","G9")
pool("P9","9→10",10,["F9_radio_maman → R3 (si R2) = la voix de maman","F9_soeur_doute → SOIN"])
arrow("G9","P9")

# ============ GARE 10 ============
card("G10",10,"G10","Serre chaude, répit cosy","Vrai repos","F+20 S+16 M+18","Plein et repartir","F+12 S+10 B+12 M-4",gain="HYDROPONIE")
arrow("P9","G10")
pool("P10","10→11",10,["fillers sœur (fleur)"])
arrow("G10","P10")

# ============ GARE 11 (combat) ============
card("G11",11,"G11","Barrage de pillards sur la voie","Foncer dans le barrage","B-18 M-6","Négocier (vivres)","F-16 S-10 M+4")
diamond("C11",11)
card("G11win",11,"G11win","si BON combat : pillards en déroute","Rafler leur butin","F+10 B+8","Passer vite","M+8")
card("G11lose",11,"G11lose","si combat RATÉ : assaut au prix fort","Panser les dégâts","F-8 M-4","Fuir","B-8 M+3")
arrow("P10","G11"); arrow("G11","C11")
arrow("C11","G11win","bon score","#3C8C3C"); arrow("C11","G11lose","raté","#C25A4A")
pool("P11","11→12",10,["fillers sœur (promesse)"])
arrow("G11win","P11"); arrow("G11lose","P11")

# ============ GARE 12 ============
card("G12",12,"G12","Vue sur le refuge nord","Lui jurer qu'ils sont là","M+18","Tempérer son espoir","M+6")
arrow("P11","G12")
pool("P12","12→13",10,[])
arrow("G12","P12")

# ============ GARE 13 ============
card("G13",13,"G13","Loco à court de bois, dernière montée","Brûler le mobilier","B+28 M-8","Descendre pousser ensemble","F-14 S-10 M+10")
arrow("P12","G13")
w('  note13 [shape=plaintext, fontsize=10, fontcolor="#8A7A5E", label="(gares 13 & 14 : AUCUNE carte d\'ambiance)"];')
arrow("G13","note13",style="invis")

# ============ GARE 14 + FINS ============
card("G14",14,"G14","Arrivée au refuge, foule des familles","Chercher vos parents","→ résolution","(idem)","→ résolution")
arrow("G13","G14")

def ending(nid, title, cond, col):
    w(f'  {nid} [shape=box, style="filled,rounded", fillcolor="{col}", color="#3A2E1F", penwidth=2, fontsize=12, label="{esc(title)}\\n{esc(cond)}"];')
ending("Esecret","FIN SECRÈTE — La voix retrouvée","sœur + SOIN≥2 + moral≥65 + R3","#F0D873")
ending("Efamille","RÉUNIS (famille)","sœur + SOIN≥2 + moral≥65","#A8D08A")
ending("Eensemble","TOUTES LES DEUX","sœur + moral≥30","#9AD0CE")
ending("Eabandon","L'ABANDON","moral à 0 / conditions non remplies","#C9BBA6")
ending("Emort","MORT","soif/faim/bois à 0 (à tout moment)","#E0958A")
arrow("G14","Esecret","si R3 suivie","#C8922A")
arrow("G14","Efamille","sœur soignée")
arrow("G14","Eensemble","sœur, moral moyen")
arrow("G14","Eabandon","moral au plus bas")
w('  edge [style=dashed, color="#C25A4A"]; G14 -> Emort [label="jauge à 0"];')

w('}')

open("/tmp/story.dot","w").write("\n".join(out))
print("dot écrit")
