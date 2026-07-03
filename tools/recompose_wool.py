from PIL import Image, ImageFilter
from collections import deque
import os

S = 'sheets'
A = '/home/user/survival/assets/characters'

# (fichier, drops, classique: canvas, scale_dim('h'/'w'), dim_cible, bottom, cx)
JOBS = {
 'sister_idle':  ('idle.png', {3,10,15,22,27,34,39,45,51,58},
                  (512,512), 'h', 352.3, 436.3, 248.1),
 'sister_walk':  ('openart-image_1783072722003_1071a4c6_1783072722193_7eca1106.png',
                  {4,10,15,22,26,34,39,46,51,58},
                  (512,512), 'h', 351.3, 431.8, 248.6),
 'sister_sleep': ('openart-image_1783072809303_02071624_1783072809397_c425c305.png',
                  {15,28},
                  (512,512), 'w', 388.0, 359.1, 254.6),
 'sister_cold':  ('openart-image_1783072837157_21fcb79c_1783072837253_3811f1ff.png',
                  set(), (198,672), 'h', 618.0, 656.0, 98.5),
 'sister_hug':   ('openart-image_1783073218538_e81f262c_1783073218597_bc854afe.png',
                  set(), (260,301), 'h', 287.2, 301.0, 129.8),
 'readduo':      ('openart-image_1783072947373_d5cbe4ac_1783072947519_f7146364.png',
                  {6,7}, (290,312), 'h', 299.7, 312.0, 144.7),
}

CANVAS = [None]

def detect_cells(path):
    im = Image.open(path).convert('RGB'); px = im.load(); W,H = im.size
    samples = []
    for y in range(0,H,5):
        for x in (0,1,W-2,W-1): samples.append(px[x,y])
    samples.sort(); canvas = samples[len(samples)//2]
    CANVAS[0] = canvas
    def isc(c,t=8): return abs(c[0]-canvas[0])<=t and abs(c[1]-canvas[1])<=t and abs(c[2]-canvas[2])<=t
    rowfrac = [sum(1 for x in range(0,W,2) if isc(px[x,y]))/(W//2) for y in range(H)]
    bands=[]; y=0
    while y<H:
        if rowfrac[y]<0.96:
            y0=y
            while y<H and rowfrac[y]<0.96: y+=1
            bands.append((y0,y))
        else: y+=1
    cells=[]
    for (y0,y1) in bands:
        if y1-y0 < 60: continue
        colfrac = [sum(1 for y in range(y0,y1) if isc(px[x,y]))/(y1-y0) for x in range(W)]
        x=0; spans=[]
        while x<W:
            if colfrac[x]<0.96:
                x0=x
                while x<W and colfrac[x]<0.96: x+=1
                if x-x0>=25: spans.append((x0,x))
            else: x+=1
        if len(spans)>=2:
            cells.extend((x0,y0,x1,y1) for x0,x1 in spans)
    return im, cells

def key_cell(im, cell):
    """Crop la case, détoure le fond (flood fill bords, tol vs médiane des
    coins) + poches très proches du fond. Retourne RGBA + bbox contenu."""
    x0,y0,x1,y1 = cell
    crop = im.crop((x0,y0,x1,y1)).convert('RGBA')
    w,h = crop.size; p = crop.load()
    corners = []
    for cx,cy in ((2,2),(w-3,2),(2,h-3),(w-3,h-3)):
        corners.append(p[cx,cy][:3])
    corners.sort(); bgc = corners[len(corners)//2]
    cvs = CANVAS[0]
    def isbg(c,t=12):
        return (abs(c[0]-bgc[0])<=t and abs(c[1]-bgc[1])<=t and abs(c[2]-bgc[2])<=t) or \
               (abs(c[0]-cvs[0])<=t and abs(c[1]-cvs[1])<=t and abs(c[2]-cvs[2])<=t)
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
            if bg[yy][xx] or isbg(p[xx,yy][:3],5):
                p[xx,yy] = (0,0,0,0)
    # nettoie les débris : composantes connexes opaques < 30 px
    seen = [[False]*w for _ in range(h)]
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or p[x0,y0][3] == 0: continue
            comp = []; qq = deque([(x0,y0)]); seen[y0][x0] = True
            while qq:
                xx,yy = qq.popleft(); comp.append((xx,yy))
                for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx,ny = xx+dx,yy+dy
                    if 0<=nx<w and 0<=ny<h and not seen[ny][nx] and p[nx,ny][3] > 0:
                        seen[ny][nx] = True; qq.append((nx,ny))
            if len(comp) < 30:
                for xx,yy in comp: p[xx,yy] = (0,0,0,0)
    return crop, crop.getchannel('A').getbbox()

def bleed(img, iters=6):
    """Étale la couleur des pixels opaques dans le transparent (anti-frange
    au resize) sans toucher l'alpha."""
    w,h = img.size; p = img.load()
    for _ in range(iters):
        todo = []
        for y in range(h):
            for x in range(w):
                if p[x,y][3] == 0:
                    rs=gs=bs=n=0
                    for dx in (-1,0,1):
                        for dy in (-1,0,1):
                            nx,ny = x+dx,y+dy
                            if 0<=nx<w and 0<=ny<h:
                                c = p[nx,ny]
                                if c[3] > 0 and not (c[0]==0 and c[1]==0 and c[2]==0 and c[3]==0):
                                    if c[3]>0: rs+=c[0]; gs+=c[1]; bs+=c[2]; n+=1
                    if n: todo.append((x,y,(rs//n,gs//n,bs//n)))
        if not todo: break
        for x,y,c in todo: p[x,y] = (c[0],c[1],c[2],0)
    return img

for name,(f, drops, cnv, sdim, target, mbot_c, mcx_c) in JOBS.items():
    im, cells = detect_cells(os.path.join(S,f))
    datas = []
    for i, cell in enumerate(cells):
        if i in drops: continue
        rgba, bb = key_cell(im, cell)
        if bb is None: continue  # case vide (grille OpenArt à trous)
        n = sum(1 for px in rgba.getdata() if px[3] > 0)
        if n < 800: continue
        datas.append((rgba, bb))
    # stats laine (coordonnées intra-case)
    dims = [(bb[2]-bb[0]) if sdim=='w' else (bb[3]-bb[1]) for _,bb in datas]
    mean_dim = sum(dims)/len(dims)
    mean_bot = sum(bb[3] for _,bb in datas)/len(datas)
    mean_cx  = sum((bb[0]+bb[2])/2 for _,bb in datas)/len(datas)
    s = target/mean_dim
    for i,(rgba,bb) in enumerate(datas, 1):
        content = rgba.crop(bb)
        content = bleed(content, 6)
        nw = max(1, round(content.width*s)); nh = max(1, round(content.height*s))
        big = content.resize((nw,nh), Image.LANCZOS)
        # unsharp sur RGB seul (l'alpha reste doux)
        r,g,b,a = big.split()
        rgb = Image.merge('RGB',(r,g,b)).filter(
            ImageFilter.UnsharpMask(radius=2, percent=80, threshold=3))
        big = Image.merge('RGBA', (*rgb.split(), a))
        cx_i = (bb[0]+bb[2])/2; bot_i = bb[3]
        tx = mcx_c + (cx_i-mean_cx)*s - nw/2
        ty = mbot_c + (bot_i-mean_bot)*s - nh
        out = Image.new('RGBA', cnv, (0,0,0,0))
        out.alpha_composite(big, (round(max(0,min(cnv[0]-nw, tx))),
                                  round(max(0,min(cnv[1]-nh, ty)))))
        out.save(f'{A}/{name}_wool_{i}.png')
    print(f'{name}: {len(datas)} frames, échelle x{s:.2f}, contenu moyen {mean_dim:.0f}px')
