#!/usr/bin/env python3
"""Simulation Train Cosy ACTUEL (PUR CARTES, plus de combat) : depart quasi a 0
(kStartStat) + ravitaillement d'arrivee par gare (grantGareSupply). Reflete
le jeu reel : voyage 100% narratif, survie geree aux cartes + au wagon.
Lancer: python3 tools/sim_current.py

Parse les vraies cartes de lib/data/cards_data.dart (paires de choix +
effets + flags), puis rejoue des milliers de runs sous les regles reelles :
  - 14 segments, fillers drawCount=4 PARTOUT (la derniere ligne droite glacee
    compte : ne pas l'ignorer, sinon on sous-estime la difficulte reelle)
  - `requires` MODELISE (comme le moteur) : une carte n'est jouee que si ses
    flags requis sont presents ; les pinned non-eligibles ne reservent pas de
    slot. -> le taux de fin 'secret' (croire a la radio 3x) est realiste, rare.
  - pertes x1.20, gains de moral x0.6 ; depart quasi a 0 (START_STAT=6)
  - ravitaillement d arrivee par gare : +9 bois/+5 soif/+7 faim/+4 moral
  - recharges wagon liees a l'engagement (careless 1 ... smart 2) : un joueur
    negligent neglige aussi le wagon, ce qui cree le spread de difficulte
  - mecanique soeur : apres flag 'aLaSoeur', -1 faim/-1 soif/+1 moral par carte
  - zone froide (gare 8+) : surconso bois
  - mort si une jauge <= 0 ; fin selon resolveTrainCosyEnding
Cible (2026-06-22, depart QUASI A ZERO demande user) :
careless ~1% / casual ~24% / smart ~99% / caring ~99%. On commence au bord
du gouffre (kStartStat=6, anneaux ~10-15%) -> pertes ramenees a x1.20. Le
bois reste la 1re cause de mort. Vrais dilemmes (gains de moral payes en
survie, cf. chien g2). Stats depart 6/6/6/6 (kStartStat).
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

# Une carte = (left, right, required_flags) ; required_flags = frozenset des
# flags exigés (les f.contains('X') POSITIFS de `requires`). Les cartes de gare
# n'ont jamais de requires -> frozenset vide (toujours éligibles).
def card_pairs(name):
    choices = extract_choices(get_func_body(name))
    return [(choices[i], choices[i+1], frozenset())
            for i in range(0, len(choices)-1, 2)]

def parse_requires(block):
    """frozenset des flags POSITIFS exigés (ignore les !f.contains anti-rejeu)."""
    req = set()
    for mm in re.finditer(r"(!?)f\.contains\('([^']+)'\)", block):
        if mm.group(1) != '!':
            req.add(mm.group(2))
    return frozenset(req)

def filler_cards(name):
    """Liste de (left, right, required_flags) pour chaque _filler(...) du paquet."""
    body = get_func_body(name)
    out = []
    for m in re.finditer(r'_filler\(', body):
        start = m.end() - 1
        end = match_paren(body, start)
        block = body[start:end+1]
        ch = extract_choices(block)
        if len(ch) < 2:
            continue
        out.append((ch[0], ch[1], parse_requires(block)))
    return out

segments = []
for i in range(1, 15):
    gare = card_pairs(f'_gare{i}')
    fill = filler_cards(f'_fill{i}')  # avec flags requis (modélise `requires`)
    draw = 4                          # drawCount=4 partout (cf. cards_data)
    segments.append((gare, fill, draw))

LOSS_MULT = 1.20
START_STAT = 6   # stats de depart quasi a 0 (kStartStat) ; ravito applique DES la gare 0
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
BASE_BOIS = 1        # carburant : bois brûlé à CHAQUE carte (toutes zones)
COLD_BOIS = 2        # surconso bois/carte dans le froid (s'ajoute à BASE_BOIS)
WOOD_START = 4       # réserve de bois de départ
WOOD_SUPPLY = {1:5,5:6,9:4}  # bûches offertes à l'arrivée de gares

# Recharges "wagon" liees a l'engagement : un joueur negligent neglige aussi
# le wagon (cuisine/eau/bois/reconfort), un attentif l'entretient. C'est ce qui
# cree le spread careless/casual (sinon le ravitaillement auto sature tout).
REFUELS_BY_STRAT = {'careless':1, 'casual':1, 'smart':2, 'caring':2}

# PANNES (rollPanne, ~22%/gare, une a la fois) : 1 poele HS (chauffe coupee ->
# surconso bois en zone froide), 2 fuite (draine la soif), 3 vitre (draine le
# moral). Reparation = geste au wagon -> liee a l'engagement : un careless
# laisse trainer, un smart/caring repare dans le segment.
PANNE_RATE = 0.22
PANNE_REPAIR = {'careless':0.2, 'casual':0.5, 'smart':1.0, 'caring':1.0}
PANNE_SEG_MALUS = 3   # points perdus par segment (fuite: soif, vitre: moral)
PANNE_POELE_COLD = 2  # surconso bois/segment si poele HS en zone froide

def run(strategy, refuels_per_seg=None):
    refuels_per_seg = REFUELS_BY_STRAT[strategy]
    stats = {'soif':START_STAT,'faim':START_STAT,'bois':START_STAT,'moral':START_STAT}
    flags = set(); soin = 0
    wood = WOOD_START
    panne = 0
    for si, (gare, fill, draw) in enumerate(segments):
        wood += WOOD_SUPPLY.get(si, 0)
        # pannes : tirage a l'arrivee (comme rollPanne dans grantGareSupply)
        if panne == 0 and random.random() < PANNE_RATE:
            panne = 1 + random.randrange(3)
        if panne:
            if panne == 1 and si >= COLD_GARE:
                stats['bois'] = max(0, stats['bois'] - PANNE_POELE_COLD)
            elif panne == 2:
                stats['soif'] = max(0, stats['soif'] - PANNE_SEG_MALUS)
            elif panne == 3:
                stats['moral'] = max(0, stats['moral'] - PANNE_SEG_MALUS)
            if random.random() < PANNE_REPAIR[strategy]:
                panne = 0
        # RAVITAILLEMENT D'ARRIVEE par gare (grantGareSupply), gare 0 incluse
        # (petit ravito de survie ; stats de base quasi a 0 -> depart au bord du
        # gouffre).
        stats['bois']=min(100,stats['bois']+9); stats['soif']=min(100,stats['soif']+5)
        stats['faim']=min(100,stats['faim']+7); stats['moral']=min(100,stats['moral']+4)
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
        # Comme le moteur (_drawFillers) : flags POTENTIELS = flags + tout flag
        # que les cartes de gare de CE segment peuvent poser (aLaSoeur/capParents
        # se posent a la carte de gare). Une carte ÉPINGLÉE (requires != null OU
        # pose un flag) ET éligible (ses flags requis subset des potentiels) est
        # toujours jouée ; l'ambiance éligible complète le budget drawCount.
        potential = set(flags)
        for (l, r, _q) in gare:
            potential |= l[1]; potential |= r[1]
        def sets_flag(c):
            (lfx, lfl), (rfx, rfl), _q = c
            return bool(lfl or rfl)
        def eligible(c, against):
            return c[2] <= against
        def is_pinned(c):
            return (bool(c[2]) or sets_flag(c)) and eligible(c, potential)
        pinned = [c for c in fill if is_pinned(c)]
        ambiance = [c for c in fill if not is_pinned(c) and eligible(c, potential)]
        slots = max(0, draw - len(pinned))  # pinned comptent dans le budget
        fillers = pinned + random.sample(ambiance, min(slots, len(ambiance)))
        random.shuffle(fillers)
        deck = list(gare) + fillers
        for card in deck:
            # éligibilité à l'émission (les cartes de gare passent toujours,
            # frozenset vide ; les fillers dont le flag requis manque sont skippés
            # -> comme _skipDeadHead du moteur).
            if not (card[2] <= flags):
                continue
            idx = pick((card[0], card[1]), stats, strategy)
            fx, fl = card[idx]
            apply(stats, fx, flags, 'aLaSoeur' in flags)
            if 'soeurProtegee' in fl: soin += 1
            flags |= fl
            if 'aLaSoeur' in flags:
                apply(stats, {'faim':-1,'soif':-1}, flags, True)
                stats['moral'] = min(100, stats['moral']+1)
            # carburant : le train brûle du bois à chaque carte (toutes zones)
            stats['bois'] = max(0, stats['bois'] - BASE_BOIS)
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
