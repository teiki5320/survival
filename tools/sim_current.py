#!/usr/bin/env python3
"""Simulation Train Cosy ACTUEL (PUR CARTES, plus de combat) : depart 25
(kStartStat) + ravitaillement d'arrivee par gare (grantGareSupply). Reflete
le jeu reel : voyage 100% narratif, survie geree aux cartes + au wagon.
Lancer: python3 tools/sim_current.py

Parse les vraies cartes de lib/data/cards_data.dart (paires de choix +
effets + flags), puis rejoue des milliers de runs sous les regles reelles :
  - 14 segments, fillers drawCount=4 PARTOUT (la derniere ligne droite glacee
    compte : ne pas l'ignorer, sinon on sous-estime la difficulte reelle)
  - pertes x1.7, gains de moral x0.6
  - ravitaillement d'arrivee par gare : +11 bois/+6 soif/+6 faim/+5 moral
  - recharges wagon liees a l'engagement (careless 1 ... smart 2) : un joueur
    negligent neglige aussi le wagon, ce qui cree le spread de difficulte
  - mecanique soeur : apres flag 'aLaSoeur', -1 faim/-1 soif/+1 moral par carte
  - zone froide (gare 8+) : surconso bois
  - mort si une jauge <= 0 ; fin selon resolveTrainCosyEnding
Cible calibree : careless ~11% / casual ~62% / smart 100% / caring 100%.
Stats depart 25/25/25/25 (kStartStat).
"""
import re, random, sys, collections

SRC = open('lib/data/cards_data.dart', encoding='utf-8').read()

def match_paren(s, i):
    """i pointe sur '(' ; retourne l'index de la ')' correspondante."""
    depth = 0
    while i < len(s):
        c = s[i]
        if c == '(': depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0: return i
        i += 1
    return -1

def parse_choice(block):
    """Extrait (effects dict, set(flags)) d'un appel _c(...)."""
    fx = {}
    m = re.search(r'fx:\s*\{([^}]*)\}', block)
    if m:
        for stat, val in re.findall(r'Stat\.(\w+):\s*(-?\d+)', m.group(1)):
            fx[stat] = int(val)
    flags = set()
    mf = re.search(r'flags:\s*\[([^\]]*)\]', block)
    if mf:
        flags = set(re.findall(r"'([^']+)'", mf.group(1)))
    return fx, flags

def extract_choices(func_body):
    """Liste ordonnée de (fx,flags) pour chaque _c(...) du corps."""
    out = []
    for m in re.finditer(r'_c\(', func_body):
        start = m.end() - 1
        end = match_paren(func_body, start)
        out.append(parse_choice(func_body[start:end+1]))
    return out

def get_func_body(name):
    # deux styles : "List<StoryCard> _gareN(..) => [ ... ]"
    #          et  "final List<StoryCard> _fillN = [ ... ]"
    m = re.search(r'List<StoryCard>\s+' + name + r'\b', SRC)
    if not m: return ''
    lb = SRC.index('[', m.end())
    depth = 0; i = lb
    while i < len(SRC):
        if SRC[i] == '[': depth += 1
        elif SRC[i] == ']':
            depth -= 1
            if depth == 0: break
        i += 1
    return SRC[lb:i+1]

# Construit les paires de cartes (left,right) par segment.
def card_pairs(name):
    choices = extract_choices(get_func_body(name))
    return [(choices[i], choices[i+1]) for i in range(0, len(choices)-1, 2)]

segments = []
for i in range(1, 15):
    gare = card_pairs(f'_gare{i}')
    fill = card_pairs(f'_fill{i}')   # les 14 segments ont des fillers (moteur)
    draw = 4                          # drawCount=4 partout (cf. cards_data)
    segments.append((gare, fill, draw))

LOSS_MULT = 1.7
REFUEL = 10
SOIN_REQ = 2
MORAL_REQ = 65

def apply(stats, fx, flags, has_sister):
    # règles moteur : pertes ×LOSS_MULT, gain moral ×0.6
    for k, v in fx.items():
        if v < 0: d = round(v * LOSS_MULT)
        elif k == 'moral': d = round(v * 0.6)
        else: d = v
        stats[k] = max(0, min(100, stats[k] + d))

def pick(card, stats, strategy):
    (lfx, lfl), (rfx, rfl) = card
    if strategy == 'careless':
        return random.choice([0, 1])
    def score(fx):
        t = dict(stats)
        for k, v in fx.items():
            d = round(v*LOSS_MULT) if v < 0 else (round(v*0.6) if k=='moral' else v)
            t[k] = max(0, min(100, t[k]+d))
        return min(t.values())
    best = 0 if score(lfx) >= score(rfx) else 1
    if strategy == 'smart':
        return best
    if strategy == 'caring':
        # joueuse qui VEUT la fin famille : s'engage à retrouver les parents
        # (capParents, gare 5) en priorité, protège la sœur ensuite, sinon
        # joue stat-optimal. Valide que la route 'famille' est atteignable.
        if 'capParents' in lfl: return 0
        if 'capParents' in rfl: return 1
        if 'soeurProtegee' in lfl: return 0
        if 'soeurProtegee' in rfl: return 1
        return best
    # 'casual' : pondère vers le meilleur choix mais se trompe 30% du temps
    return best if random.random() < 0.70 else 1-best

COLD_GARE = 7        # gare 8 (0-based) = entrée zone froide
COLD_BOIS = 2        # surconso bois/carte dans le froid
WOOD_START = 4       # réserve de bois de départ
WOOD_SUPPLY = {1:5,5:6,9:4}  # bûches offertes à l'arrivée de gares

# Recharges "wagon" liees a l'engagement : un joueur negligent neglige aussi
# le wagon (cuisine/eau/bois/reconfort), un attentif l'entretient. C'est ce qui
# cree le spread careless/casual (sinon le ravitaillement auto sature tout).
REFUELS_BY_STRAT = {'careless':1, 'casual':1, 'smart':2, 'caring':2}

def run(strategy, refuels_per_seg=None):
    refuels_per_seg = REFUELS_BY_STRAT[strategy]
    stats = {'soif':25,'faim':25,'bois':25,'moral':25}
    flags = set(); soin = 0
    wood = WOOD_START
    for si, (gare, fill, draw) in enumerate(segments):
        wood += WOOD_SUPPLY.get(si, 0)
        # COMBAT SUPPRIME. RAVITAILLEMENT D'ARRIVEE par gare (grantGareSupply,
        # calibre par simu) : remplace les ressources de l'ancien combat.
        stats['bois']=min(100,stats['bois']+11); stats['soif']=min(100,stats['soif']+6)
        stats['faim']=min(100,stats['faim']+6); stats['moral']=min(100,stats['moral']+5)
        # budget wagon : recharge les N stats les plus basses. Recharger BOIS
        # exige de brûler 1 bûche ; sans bois en réserve, on recharge la stat
        # non-bois la plus basse à la place.
        for _ in range(refuels_per_seg):
            order = sorted(stats, key=lambda k: stats[k])
            low = order[0]
            if low == 'bois' and wood <= 0:
                low = next((k for k in order if k != 'bois'), 'bois')
            if low == 'bois':
                if wood <= 0:
                    continue
                wood -= 1
            stats[low] = min(100, stats[low] + REFUEL)
        # Comme le moteur : les fillers qui POSENT un flag (progression : radio,
        # soeurProtegee...) sont TOUJOURS joues ; le reste (ambiance) est tire au
        # hasard (drawCount). -> variete sans casser les arcs.
        def _sets_flag(c):
            (lfx, lfl), (rfx, rfl) = c
            return bool(lfl or rfl)
        pinned = [c for c in fill if _sets_flag(c)]
        ambiance = [c for c in fill if not _sets_flag(c)]
        slots = max(0, draw - len(pinned))  # pinned comptent dans le budget
        fillers = pinned + random.sample(ambiance, min(slots, len(ambiance)))
        random.shuffle(fillers)
        deck = list(gare) + fillers
        for card in deck:
            idx = pick(card, stats, strategy)
            fx, fl = card[idx]
            apply(stats, fx, flags, 'aLaSoeur' in flags)
            if 'soeurProtegee' in fl: soin += 1
            flags |= fl
            if 'aLaSoeur' in flags:
                apply(stats, {'faim':-1,'soif':-1}, flags, True)
                stats['moral'] = min(100, stats['moral']+1)
            # zone froide : la loco boit plus (drain bois plat, non multiplié)
            if si >= COLD_GARE:
                stats['bois'] = max(0, stats['bois'] - COLD_BOIS)
            if min(stats.values()) <= 0:
                dead = min(stats, key=lambda k: stats[k])
                tag = 'abandon' if dead=='moral' else 'mort'
                return tag, stats, flags, dead
    # fin
    moral = stats['moral']; aSoeur = 'aLaSoeur' in flags; cap = 'capParents' in flags
    if aSoeur and cap and soin>=SOIN_REQ and moral>=MORAL_REQ and 'radio3' in flags: end='secret'
    elif aSoeur and cap and soin>=SOIN_REQ and moral>=MORAL_REQ: end='famille'
    elif aSoeur: end='ensemble'  # arriver avec la soeur = au moins ensemble
    else: end='abandon'
    return end, stats, flags, None

def trial(strategy, refuels, n=4000):
    ends = collections.Counter(); deaths = collections.Counter()
    survived = 0; famille = 0
    for _ in range(n):
        e,_s,_f,dead = run(strategy, refuels)
        ends[e]+=1
        if dead: deaths[dead]+=1
        if e in ('famille','ensemble','secret'): survived+=1
        if e=='famille': famille+=1
    return survived/n, famille/n, ends, deaths

if '--wood' in sys.argv:
    # Sweep réserve de bois : trouve un niveau où le bois devient un vrai
    # facteur de mort (sinon le mécanisme #3 ne sert à rien).
    print("Sweep bois (casual, budget=2) — survie + part des morts dues au bois")
    print(f"{'START':>5} {'supply':>16} | {'casual':>7} {'morts bois %':>12}")
    for ws, sup in [(5,{2:6,6:7,9:5}),(4,{2:4,6:5,9:3}),(3,{2:3,6:4,9:2}),
                    (2,{2:3,6:3,9:2}),(3,{6:4,9:2}),(2,{6:3,9:2})]:
        globals()['WOOD_START']=ws; globals()['WOOD_SUPPLY']=sup
        n=4000; surv=0; boisdeath=0
        for _ in range(n):
            e,_s,_f,dead = run('casual',2)
            if e in ('famille','ensemble','secret'): surv+=1
            if dead=='bois': boisdeath+=1
        print(f"{ws:>5} {str(sup):>16} | {surv*100/n:6.1f}% {boisdeath*100/n:11.1f}%")
    sys.exit(0)

print(f"Segments parsés : {len(segments)}  | gare seg1 : {len(segments[0][0])}  | filler seg1 : {len(segments[0][1])}")
print(f"REFUEL={REFUEL}  LOSS_MULT={LOSS_MULT}  SOIN_REQ={SOIN_REQ}  "
      f"WOOD_START={WOOD_START} supply={WOOD_SUPPLY}\n")
for strat in ['careless','casual','smart','caring']:
    for rf in [2]:
        rate, fam, ends, deaths = trial(strat, rf)
        top = ', '.join(f'{k}:{round(v*100/4000)}%' for k,v in ends.most_common())
        dtop = ', '.join(f'{k}:{round(v*100/4000)}%' for k,v in deaths.most_common())
        print(f'{strat:9} → survie {rate*100:5.1f}%  famille {fam*100:4.1f}%  [{top}]')
        if dtop: print(f'           morts par : {dtop}')
    print()
