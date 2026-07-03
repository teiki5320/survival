from PIL import Image, ImageFilter
import os

S = 'sheets'
A = '/home/user/survival/assets/characters'

JOBS = {
 'sister_idle':  ('openart-image_1783085010055_680929d8_1783085010119_30279357.png', 16, 8),
 'sister_walk':  ('openart-image_1783085062474_2e40a56a_1783085062522_9ef8ce43.png', 16, 8),
 'sister_sleep': ('openart-image_1783085081604_2a6ac710_1783085081692_0caa3811.png', 12, 6),
}
# cibles classiques recalculées sur les jeux réduits
def classic_stats(name, n, sdim):
    bbs = [Image.open(f'{A}/{name}_{i}.png').getchannel('A').getbbox() for i in range(1,n+1)]
    mh = sum(b[3]-b[1] for b in bbs)/n; mw = sum(b[2]-b[0] for b in bbs)/n
    return (sum((b[0]+b[2])/2 for b in bbs)/n, sum(b[3] for b in bbs)/n,
            mw if sdim=='w' else mh)

TARGETS = {
 'sister_idle':  ('h', *classic_stats('sister_idle', 16, 'h')),
 'sister_walk':  ('h', *classic_stats('sister_walk', 16, 'h')),
 'sister_sleep': ('w', *classic_stats('sister_sleep', 12, 'w')),
}

def isgreen(c):
    r,g,b = c[:3]
    return g > 90 and g > r*1.30 and g > b*1.30

def iscanvas(c):
    r,g,b = c[:3]
    return g > 200 and g > r*1.30 and g > b*1.30

def find_cells(im, cols):
    """Grille régulière : bandes de rangées détectées par lignes non-canvas,
    colonnes découpées à pas fixe W/cols (cadres trop pâles pour être fiables,
    mais la grille OpenArt est régulière — pitch vérifié)."""
    px = im.load(); W,H = im.size
    rowg = [sum(1 for x in range(0,W,2) if iscanvas(px[x,y]))/(W//2) for y in range(H)]
    bands=[]; y=0
    while y<H:
        if rowg[y]<0.96:
            y0=y
            while y<H and rowg[y]<0.96: y+=1
            bands.append((y0,y))
        else: y+=1
    # fusionne les bandes proches (case sleep = lune en haut + corps en bas,
    # séparés par du canvas) puis ne garde que les vraies rangées
    merged=[]
    for b in bands:
        if merged and b[0]-merged[-1][1] < 40 and b[1]-b[0] >= 20 and merged[-1][1]-merged[-1][0] >= 20:
            merged[-1] = (merged[-1][0], b[1])
        else: merged.append(b)
    bands = [b for b in merged if b[1]-b[0] >= 80]
    cells=[]
    pitch = W/cols
    for (y0,y1) in bands:
        for k in range(cols):
            cells.append((round(k*pitch)+6, y0+2, round((k+1)*pitch)-6, y1-2))
    return cells

def key_green(crop):
    p = crop.load(); w,h = crop.size
    for y in range(h):
        for x in range(w):
            r,g,b,a = p[x,y]
            if isgreen((r,g,b)):
                p[x,y] = (0,0,0,0)
            elif g > r and g > b and g - max(r,b) > 16:
                p[x,y] = (r, max(r,b), b, a)  # despill
    return crop

for name,(f, n, cols) in JOBS.items():
    sdim, mcx_c, mbot_c, target = TARGETS[name]
    cnv = Image.open(f'{A}/{name}_1.png').size
    im = Image.open(os.path.join(S,f)).convert('RGB')
    cells = find_cells(im, cols)
    assert len(cells) == n, (name, len(cells))
    datas=[]
    for cell in cells:
        crop = im.crop(cell).convert('RGBA')
        crop = key_green(crop)
        bb = crop.getchannel('A').getbbox()
        datas.append((crop, bb))
    dims = [(bb[2]-bb[0]) if sdim=='w' else (bb[3]-bb[1]) for _,bb in datas]
    mean_dim = sum(dims)/len(dims)
    mean_bot = sum(bb[3] for _,bb in datas)/len(datas)
    mean_cx  = sum((bb[0]+bb[2])/2 for _,bb in datas)/len(datas)
    s = target/mean_dim
    for i,(crop,bb) in enumerate(datas, 1):
        content = crop.crop(bb)
        nw = max(1, round(content.width*s)); nh = max(1, round(content.height*s))
        big = content.resize((nw,nh), Image.LANCZOS)
        cx_i = (bb[0]+bb[2])/2; bot_i = bb[3]
        tx = mcx_c + (cx_i-mean_cx)*s - nw/2
        ty = mbot_c + (bot_i-mean_bot)*s - nh
        out = Image.new('RGBA', cnv, (0,0,0,0))
        out.alpha_composite(big, (round(max(0,min(cnv[0]-nw, tx))),
                                  round(max(0,min(cnv[1]-nh, ty)))))
        out.save(f'{A}/{name}_wool_{i}.png')
    print(f'{name}: {n} frames, échelle x{s:.2f}, contenu source {mean_dim:.0f}px')
