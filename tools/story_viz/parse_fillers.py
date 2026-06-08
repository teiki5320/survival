#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import re, json

src = open("/home/user/survival/lib/data/cards_data.dart", encoding="utf-8").read()

def split_top(s):
    """Découpe sur les virgules de niveau 0 (respecte (), {}, [], chaînes)."""
    args=[]; depth=0; instr=False; q=None; esc=False; cur=''
    for ch in s:
        if instr:
            cur+=ch
            if esc: esc=False
            elif ch=='\\': esc=True
            elif ch==q: instr=False
            continue
        if ch in '"\'':
            instr=True; q=ch; cur+=ch; continue
        if ch in '([{': depth+=1; cur+=ch; continue
        if ch in ')]}': depth-=1; cur+=ch; continue
        if ch==',' and depth==0: args.append(cur.strip()); cur=''; continue
        cur+=ch
    if cur.strip(): args.append(cur.strip())
    return args

def find_call(text, start):
    """À partir de l'indice d'un '(', renvoie (contenu, index_après_')')."""
    depth=0; instr=False; q=None; esc=False; i=start
    while i < len(text):
        ch=text[i]
        if instr:
            if esc: esc=False
            elif ch=='\\': esc=True
            elif ch==q: instr=False
        else:
            if ch in '"\'': instr=True; q=ch
            elif ch=='(': depth+=1
            elif ch==')':
                depth-=1
                if depth==0: return text[start+1:i], i+1
        i+=1
    return text[start+1:], len(text)

def unq(s):
    s=s.strip()
    if len(s)>=2 and s[0] in '"\'' and s[-1]==s[0]: return s[1:-1]
    return s

STAT={'moral':'M','faim':'F','soif':'S','bois':'B'}
def parse_fx(arg):
    # arg ressemble à "fx: {Stat.bois: 12, Stat.faim: -4}"
    m=re.search(r'\{(.*)\}', arg, re.S)
    if not m: return ''
    parts=[]
    for kv in m.group(1).split(','):
        kv=kv.strip()
        if not kv: continue
        mm=re.match(r'Stat\.(\w+)\s*:\s*(-?\d+)', kv)
        if mm:
            k=STAT.get(mm.group(1), mm.group(1)); v=int(mm.group(2))
            parts.append(f"{k}{'+' if v>=0 else ''}{v}")
    return ' '.join(parts)

def parse_flags(arg):
    m=re.search(r'\[(.*?)\]', arg, re.S)
    if not m: return []
    return [unq(x) for x in m.group(1).split(',') if x.strip()]

def parse_c(text):
    """Parse un appel _c(...) -> (label, fx, flags)."""
    idx=text.find('_c(')
    if idx<0: return ('?','',[])
    content,_=find_call(text, text.find('(', idx))
    args=split_top(content)
    label=unq(args[0]) if args else '?'
    fx=''; flags=[]
    for a in args[1:]:
        if a.startswith('fx'): fx=parse_fx(a)
        elif a.startswith('flags'): flags=parse_flags(a)
    return (label,fx,flags)

GAINMAP={'aLeChien':'CHIEN','aLaSoeur':'SŒUR','aLaRadio':'RADIO','radio1':'R1',
 'radio2':'R2','radio3':'R3','asset_bed':'LIT','asset_filter':'FILTRE',
 'asset_hydro':'HYDRO','indiceSoeur':'indice','capParents':'cap','soeurProtegee':'SOIN'}
def gains(flags):
    return [GAINMAP.get(f,f) for f in flags if f in GAINMAP]

def parse_requires(arg):
    cs=re.findall(r"contains\('([^']+)'\)", arg)
    neg=re.findall(r"!\s*f\.contains\('([^']+)'\)", arg)
    out=[]
    for c in cs:
        out.append(('!' if c in neg else '')+c)
    return out

# --- Parse chaque _fillN ---
segments={}
for n in range(1,13):
    m=re.search(rf'final List<StoryCard> _fill{n} = \[', src)
    if not m: continue
    start=m.end()
    # trouve le ']' fermant du niveau de la liste
    depth=1; i=start; instr=False; q=None; esc=False
    while i<len(src) and depth>0:
        ch=src[i]
        if instr:
            if esc: esc=False
            elif ch=='\\': esc=True
            elif ch==q: instr=False
        else:
            if ch in '"\'': instr=True; q=ch
            elif ch=='[': depth+=1
            elif ch==']': depth-=1
        i+=1
    block=src[start:i-1]
    fillers=[]
    pos=0
    while True:
        j=block.find('_filler(', pos)
        if j<0: break
        content,end=find_call(block, block.find('(', j))
        pos=end
        args=split_top(content)
        fid=unq(args[0]); text=unq(args[1]) if len(args)>1 else ''
        # left/right = args qui contiennent _c(
        cargs=[a for a in args if a.strip().startswith('_c(')]
        left=parse_c(cargs[0]) if len(cargs)>0 else ('?','',[])
        right=parse_c(cargs[1]) if len(cargs)>1 else ('?','',[])
        req=[]
        for a in args:
            if a.strip().startswith('requires'): req=parse_requires(a)
        oneshot=any(a.strip().startswith('oneshot') for a in args)
        fillers.append({'id':fid,'text':text,'left':left,'right':right,
                        'requires':req,'oneshot':oneshot})
    segments[n]=fillers

json.dump(segments, open('/tmp/fillers.json','w'), ensure_ascii=False, indent=1)
for n in sorted(segments): print(n, len(segments[n]), 'fillers')
