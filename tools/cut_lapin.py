from PIL import Image
from collections import deque
import glob, os

T = 'tenue2'
A = '/home/user/survival/assets/characters'
files = sorted(glob.glob(f'{T}/*.png'))

# (index fichier, anim, cols, drops, options)
JOBS = [
 (1,  'wake_up',     8,  set(), {}),
 (2,  'warm_hands',  8,  set(), {}),
 (3,  'use_back',    8,  set(), {}),
 (4,  'stretch',     8,  set(), {}),
 (5,  'petdog',      5,  {5,6,7,8,9}, {'remap': [1,2,3,4,5,4,5,4,5], 'edge_frac': True}),
 (6,  'pickup',      8,  set(), {}),
 (7,  'read',        8,  set(), {}),
 (8,  'eat',         8,  set(), {}),
 (9,  'drink',       8,  set(), {}),
 (10, 'dance',       10, {2,8,11,19}, {}),
 (11, 'carry_walk',  8,  set(), {}),
 (12, 'walk_right',  8,  set(), {}),
 (14, 'sleep_right', 8,  set(), {'keep_bottom': True, 'fixed_rows': 2}),
]

def iscanvas(c):
    r,g,b = c[:3]
    return g > 200 and g > r*1.30 and g > b*1.30

def isgreenish(c):
    r,g,b = c[:3]
    return g > 90 and g > r*1.30 and g > b*1.30

def find_bands(im, merge=False, minh=80):
    px = im.load(); W,H = im.size
    rowg = [sum(1 for x in range(0,W,2) if iscanvas(px[x,y]))/(W//2) for y in range(H)]
    # seuil adaptatif : certaines planches ont des gouttières polluées
    # (liseré sombre) -> on descend le seuil jusqu'à trouver 2 rangées
    bands = []
    for thr in (0.96, 0.90, 0.85):
        bands=[]; y=0
        while y<H:
            if rowg[y]<thr:
                y0=y
                while y<H and rowg[y]<thr: y+=1
                bands.append((y0,y))
            else: y+=1
        if sum(1 for a,b in bands if b-a >= minh) >= 2:
            break
    if merge:
        merged=[]
        for b in bands:
            if merged and b[0]-merged[-1][1] < 40 and b[1]-b[0] >= 20 and merged[-1][1]-merged[-1][0] >= 20:
                merged[-1] = (merged[-1][0], b[1])
            else: merged.append(b)
        bands = merged
    return [b for b in bands if b[1]-b[0] >= minh]

def key_cell(crop):
    """Détoure le fond de la case : flood fill des bords sur la couleur des
    coins (gère cases vertes ET sombres) + balayage du vert vif + despill."""
    p = crop.load(); w,h = crop.size
    corners = sorted(p[cx,cy][:3] for cx,cy in ((2,2),(w-3,2),(2,h-3),(w-3,h-3)))
    bgc = corners[len(corners)//2]
    def isbg(c,t=14):
        return (abs(c[0]-bgc[0])<=t and abs(c[1]-bgc[1])<=t and abs(c[2]-bgc[2])<=t) \
               or isgreenish(c)
    bg = [[False]*w for _ in range(h)]
    q = deque()
    for xx in range(w):
        for yy in (0,h-1):
            if not bg[yy][xx] and isbg(p[xx,yy][:3]): bg[yy][xx]=True; q.append((xx,yy))
    for yy in range(h):
        for xx in (0,w-1):
            if not bg[yy][xx] and isbg(p[xx,yy][:3]): bg[yy][xx]=True; q.append((xx,yy))
    while q:
        xx,yy = q.popleft()
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx,ny = xx+dx, yy+dy
            if 0<=nx<w and 0<=ny<h and not bg[ny][nx] and isbg(p[nx,ny][:3]):
                bg[ny][nx]=True; q.append((nx,ny))
    for yy in range(h):
        for xx in range(w):
            c = p[xx,yy]
            if bg[yy][xx] or isgreenish(c[:3]):
                p[xx,yy] = (0,0,0,0)
            elif c[1] > c[0] and c[1] > c[2] and c[1]-max(c[0],c[2]) > 16:
                p[xx,yy] = (c[0], max(c[0],c[2]), c[2], c[3])
    return crop

def components(crop):
    p = crop.load(); w,h = crop.size
    seen = [[False]*w for _ in range(h)]
    comps=[]
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or p[x0,y0][3]==0: continue
            comp=[]; q=deque([(x0,y0)]); seen[y0][x0]=True
            while q:
                xx,yy=q.popleft(); comp.append((xx,yy))
                for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx,ny=xx+dx,yy+dy
                    if 0<=nx<w and 0<=ny<h and not seen[ny][nx] and p[nx,ny][3]>0:
                        seen[ny][nx]=True; q.append((nx,ny))
            comps.append(comp)
    return comps

def classic_stats(name, n, sdim):
    bbs = [Image.open(f'{A}/{name}_{i}.png').getchannel('A').getbbox() for i in range(1,n+1)]
    mh = sum(b[3]-b[1] for b in bbs)/n; mw = sum(b[2]-b[0] for b in bbs)/n
    return (sum((b[0]+b[2])/2 for b in bbs)/n, sum(b[3] for b in bbs)/n,
            mw if sdim=='w' else mh)

for idx, anim, cols, drops, opts in JOBS:
    im = Image.open(files[idx]).convert('RGB')
    W,H = im.size
    if opts.get('fixed_rows'):
        nr = opts['fixed_rows']
        rh = H // nr
        bands = [(r*rh+4, (r+1)*rh-6) for r in range(nr)]
    else:
        bands = find_bands(im, merge=False)
    pitch = W/cols
    cells=[]
    for (y0,y1) in bands:
        for k in range(cols):
            cells.append((round(k*pitch)+5, y0+2, round((k+1)*pitch)-5, y1-2))
    kept = [c for i,c in enumerate(cells) if i not in drops]
    # nb de frames classiques attendues
    n_classic = len(glob.glob(f'{A}/{anim}_[0-9]*.png'))
    datas=[]
    for cell in kept:
        crop = im.crop(cell).convert('RGBA')
        crop = key_cell(crop)
        w2,h2 = crop.size
        comps = components(crop)
        p = crop.load()
        biggest = max((len(c) for c in comps), default=0)
        for comp in comps:
            ys = [yy for _,yy in comp]; xs = [xx for xx,_ in comp]
            cw2 = max(xs)-min(xs)+1
            touches_edge = min(xs) <= 12 or max(xs) >= w2-13
            if len(comp) < 30:
                for xx,yy in comp: p[xx,yy]=(0,0,0,0)
            elif opts.get('keep_bottom') and max(ys) < h2*0.55:
                # déchet flottant au-dessus du sprite du bas (planche sleep)
                for xx,yy in comp: p[xx,yy]=(0,0,0,0)
            elif touches_edge and cw2 <= 16 and (max(ys)-min(ys)) > h2*0.3:
                # trait vertical de bord de case (cadres sombres)
                for xx,yy in comp: p[xx,yy]=(0,0,0,0)
            elif touches_edge and len(comp) < biggest*(0.4 if opts.get('edge_frac') else 0.12):
                # fragment du sprite de la case voisine qui déborde
                for xx,yy in comp: p[xx,yy]=(0,0,0,0)
        bb = crop.getchannel('A').getbbox()
        datas.append((crop, bb))
    remap = opts.get('remap')
    if remap:
        datas = [datas[i-1] for i in remap]
    assert len(datas) == n_classic, (anim, len(datas), n_classic)
    sdim = 'w' if anim == 'sleep_right' else 'h'
    mcx_c, mbot_c, target = classic_stats(anim, n_classic, sdim)
    cnv = Image.open(f'{A}/{anim}_1.png').size
    dims = [(bb[2]-bb[0]) if sdim=='w' else (bb[3]-bb[1]) for _,bb in datas]
    mean_dim = sum(dims)/len(dims)
    mean_bot = sum(bb[3] for _,bb in datas)/len(datas)
    mean_cx  = sum((bb[0]+bb[2])/2 for _,bb in datas)/len(datas)
    s = target/mean_dim
    warn=''
    for i,(crop,bb) in enumerate(datas, 1):
        content = crop.crop(bb)
        nw = max(1, round(content.width*s)); nh = max(1, round(content.height*s))
        if nw > cnv[0] or nh > cnv[1]:
            f2 = min(cnv[0]/nw, cnv[1]/nh)
            nw = max(1,int(nw*f2)); nh = max(1,int(nh*f2))
            warn=' ⚠️ contenu réduit pour tenir dans le canvas'
        big = content.resize((nw,nh), Image.LANCZOS)
        cx_i = (bb[0]+bb[2])/2; bot_i = bb[3]
        tx = mcx_c + (cx_i-mean_cx)*s - nw/2
        ty = mbot_c + (bot_i-mean_bot)*s - nh
        out = Image.new('RGBA', cnv, (0,0,0,0))
        out.alpha_composite(big, (round(max(0,min(cnv[0]-nw, tx))),
                                  round(max(0,min(cnv[1]-nh, ty)))))
        out.save(f'{A}/{anim}_lapin_{i}.png')
    print(f'{anim}: {len(datas)} frames (cible {n_classic}), échelle x{s:.2f}, src {mean_dim:.0f}px{warn}')
