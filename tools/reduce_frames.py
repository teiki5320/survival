#!/usr/bin/env python3
"""Réduit des animations de Shen de 49 -> 25 frames (garde 1 frame sur 2),
de façon RÉVERSIBLE : les 49 frames originales sont d'abord copiées dans
`frames_backup_49/characters/`.

- HALVE : garde les indices impairs (1,3,...,49 = 25 frames), renumérote 1..25.
- TRIM_USEBACK : `use_back` n'est lu qu'en 24 frames -> on retire 25..49 (inutiles).

Restaurer : `python3 tools/reduce_frames.py --restore`.
"""
import os
import shutil
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..')
CHAR = os.path.join(ROOT, 'assets', 'characters')
BACKUP = os.path.join(ROOT, 'frames_backup_49', 'characters')

HALVE = ['idle_right', 'walk_right', 'sleep_right', 'dance', 'wake_up',
         'read', 'eat', 'carry_walk', 'warm_hands', 'stretch']
TRIM = {'use_back': 24}  # garde 1..24, retire le reste


def p(name, i):
    return os.path.join(CHAR, f'{name}_{i}.png')


def bk(name, i):
    return os.path.join(BACKUP, f'{name}_{i}.png')


def count(name):
    i = 1
    while os.path.exists(p(name, i)):
        i += 1
    return i - 1


def backup_all(name, n):
    os.makedirs(BACKUP, exist_ok=True)
    for i in range(1, n + 1):
        if not os.path.exists(bk(name, i)):
            shutil.copy2(p(name, i), bk(name, i))


def reduce():
    for name in HALVE:
        n = count(name)
        if n != 49:
            print(f'  ! {name}: {n} frames (attendu 49) -> skip')
            continue
        backup_all(name, n)
        kept = [i for i in range(1, n + 1) if i % 2 == 1]  # 25 impairs
        tmp = []
        for new, old in enumerate(kept, 1):
            t = os.path.join(CHAR, f'.__{name}_{new}.png')
            shutil.copy2(p(name, old), t)
            tmp.append((new, t))
        for i in range(1, n + 1):
            os.remove(p(name, i))
        for new, t in tmp:
            os.rename(t, p(name, new))
        print(f'  {name}: 49 -> {len(kept)} frames')

    for name, keep in TRIM.items():
        n = count(name)
        if n <= keep:
            print(f'  ! {name}: {n} <= {keep} -> rien à retirer')
            continue
        backup_all(name, n)
        for i in range(keep + 1, n + 1):
            os.remove(p(name, i))
        print(f'  {name}: {n} -> {keep} frames (retiré {n - keep} inutiles)')


def restore():
    if not os.path.isdir(BACKUP):
        print('Aucun backup trouvé.')
        return
    names = set()
    for f in os.listdir(BACKUP):
        names.add(f.rsplit('_', 1)[0])
    for name in names:
        # supprime les frames réduites actuelles
        i = 1
        while os.path.exists(p(name, i)):
            os.remove(p(name, i))
            i += 1
        # restaure depuis backup
        i = 1
        while os.path.exists(bk(name, i)):
            shutil.copy2(bk(name, i), p(name, i))
            i += 1
        print(f'  {name}: restauré {i - 1} frames')


if __name__ == '__main__':
    if '--restore' in sys.argv:
        print('Restauration des frames originales...')
        restore()
    else:
        print('Réduction 49 -> 25 (réversible, backup dans frames_backup_49/)...')
        reduce()
    print('Terminé.')
