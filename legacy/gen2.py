import json, sys, math
W=H=32
def canvas(): return [['.']*W for _ in range(H)]
def inb(x,y): return 0<=x<W and 0<=y<H
def capsule(x0,y0,x1,y1,r):
    m=[[False]*W for _ in range(H)]
    dx,dy=x1-x0,y1-y0; L2=dx*dx+dy*dy
    for y in range(H):
        for x in range(W):
            px,py=x+0.5,y+0.5
            t=0 if L2==0 else max(0,min(1,((px-x0)*dx+(py-y0)*dy)/L2))
            cx,cy=x0+dx*t,y0+dy*t
            if (px-cx)**2+(py-cy)**2<=r*r: m[y][x]=True
    return m
def ellipse(cx,cy,rx,ry):
    m=[[False]*W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            px,py=x+0.5,y+0.5
            if ((px-cx)/rx)**2+((py-cy)/ry)**2<=1: m[y][x]=True
    return m
def tri(x0,y0,x1,y1,x2,y2):
    m=[[False]*W for _ in range(H)]
    def sgn(px,py,ax,ay,bx,by): return (px-bx)*(ay-by)-(ax-bx)*(py-by)
    for y in range(H):
        for x in range(W):
            px,py=x+0.5,y+0.5
            d1=sgn(px,py,x0,y0,x1,y1);d2=sgn(px,py,x1,y1,x2,y2);d3=sgn(px,py,x2,y2,x0,y0)
            neg=(d1<0) or (d2<0) or (d3<0); pos=(d1>0) or (d2>0) or (d3>0)
            m[y][x]= not(neg and pos)
    return m
def union(a,b): return [[a[y][x] or b[y][x] for x in range(W)] for y in range(H)]
def inter(a,b): return [[a[y][x] and b[y][x] for x in range(W)] for y in range(H)]
def paint(c,m,mid,dark,light,outline='1',shade=True):
    def inm(x,y): return inb(x,y) and m[y][x]
    for y in range(H):
        for x in range(W):
            if not m[y][x]: continue
            edge = not(inm(x-1,y) and inm(x+1,y) and inm(x,y-1) and inm(x,y+1))
            if edge and outline: c[y][x]=outline; continue
            col=mid
            if shade:
                if not inm(x-2,y-1) or not inm(x-1,y-2): col=light
                elif not inm(x+2,y+1) or not inm(x+1,y+2): col=dark
            c[y][x]=col
def px(c,x,y,k):
    if inb(x,y): c[y][x]=k

# palette indices: 1 outline, 2 fur dark,3 fur mid,4 fur light,5 diaper,6 diaper shade,7 acc dark,8 acc light,
# 9 eye white, a pupil, b pink, c belly light, d nose, e highlight, f misc
CH = {
 'goo':  dict(name='BRANDON',  skin=('3','2','4'), limb=None, head=(6.5,6.0), torso=5.0, belly=True, patch=False,
              pal=['#2a1a2e','#c98a66','#f0b48e','#ffd9bd','#f8f8ff','#c2c6d8','#6a3a22','#a0603a','#ffffff','#1a1020','#f08aa0','#ffe0c8','#7a4a28','#ffffff','#ffe066']),
 'pup':  dict(name='ARLO',  skin=('3','2','4'), limb=None, head=(6.5,6.0), torso=5.4, belly=True, patch=True,
              pal=['#2a1a1e','#a8703a','#dca060','#f4c888','#f8f8ff','#c2c6d8','#6a3a22','#9a5a30','#ffffff','#1a1020','#f08aa0','#fbe8c0','#1a1020','#ffffff','#ffe066']),
 'kit':  dict(name='DAWN',  skin=('3','2','4'), limb=None, head=(6.5,6.0), torso=4.4, belly=False, patch=True,
              pal=['#1e1e30','#6a6a8a','#a0a0c0','#d0d0e8','#f8f8ff','#c2c6d8','#505070','#f0a0c0','#ffffff','#1a1020','#f08aa0','#f0f0ff','#f080a0','#ffffff','#ffe066']),
 'oink': dict(name='CHRIS', skin=('3','2','4'), limb=None, head=(6.8,6.0), torso=6.0, belly=True, patch=False,
              pal=['#3a1a2e','#d87090','#f8a0b8','#ffc8d8','#f8f8ff','#c2c6d8','#c05878','#ffb8cc','#ffffff','#1a1020','#f08aa0','#ffd8e4','#a04060','#ffffff','#ffe066']),
 'quack':dict(name='ISAAC',skin=('3','2','4'), limb=None, head=(6.5,6.0), torso=5.2, belly=True, patch=False,
              pal=['#3a2a10','#d0a020','#f8d840','#fff090','#f8f8ff','#c2c6d8','#f08020','#ffb050','#ffffff','#1a1020','#f08aa0','#fff8c0','#c05010','#ffffff','#ffe066']),
 'cub':  dict(name='TEDDY',  skin=('3','2','4'), limb=None, head=(7.0,6.2), torso=6.0, belly=True, patch=True,
              pal=['#2a1810','#7a4a28','#a87040','#d09860','#f8f8ff','#c2c6d8','#5a3018','#c89060','#ffffff','#1a1020','#f08aa0','#e8c898','#1a1020','#ffffff','#ffe066']),
 'hops': dict(name='PIP', skin=('3','2','4'), limb=None, head=(6.5,5.0), torso=4.6, belly=False, patch=True,
              pal=['#2a2a3a','#b8b8c8','#ececf4','#ffffff','#f0f0ff','#b8c0d8','#c0c0d0','#ffb0c8','#ffffff','#1a1020','#f08aa0','#ffffff','#f080a0','#ffffff','#ffe066']),
 'bugsy':dict(name='BLUE',skin=('3','2','4'), limb=('7','7','8'), head=(6.0,5.5), torso=5.4, belly=False, patch=False,
              pal=['#1a1020','#a82020','#e03030','#ff6060','#f8f8ff','#c2c6d8','#2a2030','#505060','#ffffff','#1a1020','#f08aa0','#e0f0ff','#000000','#ffffff','#ffe066']),
}
KINDS=['goo','pup','kit','oink','quack','cub','hops','bugsy']

POSES = {
 'idle':  dict(neck=(14,13),hip=(14,22),barm=((9,18),(11,15)),farm=((19,18),(21,15)),bleg=((10,27),(9,31)),fleg=((18,27),(19,31))),
 'walk1': dict(neck=(14,13),hip=(14,22),barm=((9,18),(11,15)),farm=((19,18),(21,15)),bleg=((8,27),(6,31)),fleg=((20,27),(22,31))),
 'walk2': dict(neck=(14,13),hip=(14,22),barm=((9,18),(11,15)),farm=((19,18),(21,15)),bleg=((12,27),(13,31)),fleg=((16,27),(15,31))),
 'punch': dict(neck=(16,13),hip=(13,22),barm=((11,18),(13,15)),farm=((23,15),(29,15)),bleg=((9,27),(8,31)),fleg=((19,27),(20,31))),
 'kick':  dict(neck=(12,13),hip=(13,21),barm=((7,17),(9,14)),farm=((17,17),(19,14)),bleg=((9,27),(8,31)),fleg=((23,20),(29,18))),
 'crouch':dict(neck=(14,19),hip=(14,26),barm=((9,23),(11,21)),farm=((19,23),(21,21)),bleg=((8,29),(6,31)),fleg=((20,29),(22,31))),
 'jump':  dict(neck=(14,11),hip=(14,20),barm=((8,10),(7,6)),farm=((20,10),(21,6)),bleg=((11,25),(9,28)),fleg=((17,25),(20,28))),
 'hit':   dict(neck=(11,14),hip=(14,22),barm=((6,15),(3,12)),farm=((8,19),(5,17)),bleg=((10,27),(8,31)),fleg=((18,27),(20,31)),headoff=(-2,0),hurt=True),
 'block': dict(neck=(14,13),hip=(14,22),barm=((18,19),(19,13)),farm=((21,20),(21,14)),bleg=((10,27),(9,31)),fleg=((18,27),(19,31))),
 'ko':    dict(neck=(10,27),hip=(19,26),barm=((6,22),(3,21)),farm=((13,22),(12,19)),bleg=((25,29),(30,30)),fleg=((24,26),(29,27)),headc=(6,25),hurt=True),
 'super': dict(neck=(14,12),hip=(14,21),barm=((8,10),(7,5)),farm=((20,10),(21,5)),bleg=((8,27),(6,31)),fleg=((20,27),(22,31))),
 'ckick': dict(neck=(12,19),hip=(12,26),barm=((7,23),(9,21)),farm=((17,22),(19,20)),bleg=((8,29),(6,31)),fleg=((20,27),(29,27))),
}
ORDER=['idle','walk1','walk2','punch','kick','crouch','jump','hit','block','ko','super','ckick']

def limb(c,ch,a,b,r):
    col = ch['limb'] or ch['skin']
    paint(c,capsule(a[0],a[1],b[0],b[1],r),*col)
def hand(c,ch,p,r=2.5):
    col = ch['limb'] or ch['skin']
    paint(c,ellipse(p[0],p[1],r,r-0.2),*col)
def foot(c,ch,p,kind):
    col = ch['limb'] or ch['skin']
    if kind=='quack': col=('7','7','8')
    rx=2.8
    if kind=='hops': rx=3.6
    paint(c,ellipse(p[0]+0.5,p[1]-0.5,rx,1.8),*col)

def draw(kind,pname):
    ch=CH[kind]; p=POSES[pname]; c=canvas()
    neck=p['neck']; hip=p['hip']; sh=(neck[0],neck[1]+2)
    rx,ry=ch['head']
    hc = p.get('headc') or (neck[0]+p.get('headoff',(0,0))[0], neck[1]-ry+1+p.get('headoff',(0,0))[1])
    hurt=p.get('hurt',False)
    lying = pname=='ko'
    skin=ch['skin']
    # --- tails (behind) ---
    tx,ty=hip[0]-ch['torso']-1,hip[1]-1
    if kind=='pup': limb(c,ch,(tx+1,ty),(tx-2,ty-5),1.8)
    if kind=='kit':
        paint(c,capsule(tx+1,ty,tx-4,ty-5,1.6),*skin); paint(c,capsule(tx-4,ty-5,tx-2,ty-10,1.6),*skin)
        px(c,int(tx-2),int(ty-10),'7')
    if kind=='oink':
        for (dx,dy) in [(0,0),(-1,-1),(-2,-2),(-1,-3),(0,-2)]: px(c,int(tx+dx),int(ty+dy),'3')
        for (dx,dy) in [(-1,0),(-2,-1),(-3,-2),(-2,-3),(-1,-4),(0,-3)]: px(c,int(tx+dx),int(ty+dy),'1')
    if kind=='quack': paint(c,tri(tx+1,ty+1,tx-5,ty-5,tx-1,ty-6),*skin)
    if kind=='cub': paint(c,ellipse(tx,ty,2.0,1.8),*skin)
    if kind=='hops': paint(c,ellipse(tx,ty,2.4,2.2),'c','6','c')
    if kind=='bugsy':
        paint(c,ellipse(neck[0]-4,(neck[1]+hip[1])/2-1,4.0,5.5),'c','c','e')
    # --- back arm / back leg ---
    e,hd=p['barm']; limb(c,ch,(sh[0]-2,sh[1]),e,2.3); limb(c,ch,e,hd,2.0); hand(c,ch,hd)
    k,ft=p['bleg']; hj=(hip[0]-2,hip[1]+1); limb(c,ch,hj,k,2.6); limb(c,ch,k,ft,2.3); foot(c,ch,ft,kind)
    # --- torso ---
    tr=ch['torso']
    tm=capsule(neck[0],neck[1],hip[0],hip[1],tr)
    if ch['belly']: tm=union(tm,ellipse((neck[0]+hip[0])/2+1,(neck[1]+hip[1])/2+2,tr+1.0,tr-0.5))
    paint(c,tm,*skin)
    if ch['patch']:
        pm=inter(tm,ellipse((neck[0]+hip[0])/2+2,(neck[1]+hip[1])/2+1,tr-1.5,tr-1.0))
        for y in range(H):
            for x in range(W):
                if pm[y][x] and c[y][x]!='1': c[y][x]='c'
    if kind=='bugsy':
        for (dx,dy) in [(-2,-3),(2,-1),(-1,2),(3,3),(-3,1)]:
            bx,by=int((neck[0]+hip[0])/2+dx),int((neck[1]+hip[1])/2+dy)
            if inb(bx,by) and c[by][bx] in '234': c[by][bx]='1'
    # diaper
    dm=[[tm[y][x] and y>=hip[1]-3 for x in range(W)] for y in range(H)]
    dm=union(dm,ellipse(hip[0],hip[1]+1,tr+1.5,3.5))
    if lying:
        dm=[[tm[y][x] and x>=hip[1]-3 and x>=hip[0]-3 for x in range(W)] for y in range(H)]
        dm=union(dm,ellipse(hip[0]+1,hip[1],3.5,tr+1.5))
    paint(c,dm,'5','6','5')
    # belly button
    bx,by=int((neck[0]+hip[0])/2)+1,int((neck[1]+hip[1])/2)
    if inb(bx,by) and c[by][bx] in '3c': c[by][bx]='2'
    # --- front leg / front arm ---
    k,ft=p['fleg']; hj=(hip[0]+2,hip[1]+1); limb(c,ch,hj,k,2.6); limb(c,ch,k,ft,2.3); foot(c,ch,ft,kind)
    e,hd=p['farm']; limb(c,ch,(sh[0]+2,sh[1]),e,2.3); limb(c,ch,e,hd,2.0); hand(c,ch,hd)
    # --- ears behind head ---
    cx,cy=hc
    if kind=='kit':
        paint(c,tri(cx-5,cy-3,cx-4,cy-9,cx-1,cy-5),*skin); paint(c,tri(cx+1,cy-5,cx+3,cy-9,cx+5,cy-3),*skin)
    if kind=='oink':
        paint(c,tri(cx-5,cy-3,cx-5,cy-8,cx-1,cy-5),*skin); paint(c,tri(cx+1,cy-5,cx+4,cy-8,cx+5,cy-3),*skin)
    if kind=='cub':
        paint(c,ellipse(cx-4.5,cy-4.5,2.6,2.6),*skin); paint(c,ellipse(cx+4.5,cy-4.5,2.6,2.6),*skin)
        px(c,int(cx-5),int(cy-5),'8'); px(c,int(cx+4),int(cy-5),'8'); px(c,int(cx-4),int(cy-5),'8'); px(c,int(cx+5),int(cy-5),'8')
    if kind=='hops':
        paint(c,capsule(cx-2,cy-3,cx-4,cy-11,1.9),*skin); paint(c,capsule(cx+2,cy-3,cx+2,cy-11,1.9),*skin)
        for yy in range(int(cy-9),int(cy-5)): px(c,int(cx-3-(yy-(cy-9))//3),yy,'8'); px(c,int(cx+2),yy,'8')
    if kind=='bugsy':
        for (ax,bx_) in [(cx-2,cx-4),(cx+2,cx+4)]:
            for yy in range(int(cy-ry-1),int(cy-ry-5),-1): px(c,int(ax+(bx_-ax)*(cy-ry-1-yy)/4),yy,'1')
            px(c,int(bx_),int(cy-ry-5),'8'); px(c,int(bx_)+1,int(cy-ry-5),'8'); px(c,int(bx_),int(cy-ry-6),'8'); px(c,int(bx_)+1,int(cy-ry-6),'8')
    # --- head ---
    hcol = ch['limb'] if kind=='bugsy' else skin
    paint(c,ellipse(cx,cy,rx,ry),*hcol)
    if kind=='kit':
        for (dx,dy) in [(-3,-2),(-3,-3),(1,-3),(1,-2)]:
            if inb(int(cx+dx),int(cy+dy)): c[int(cy+dy)][int(cx+dx)]='c' if c[int(cy+dy)][int(cx+dx)]!='1' else '1'
    # snouts / muzzles
    ex=int(cx); ey=int(cy)
    if kind=='pup':
        paint(c,ellipse(cx+4.5,cy+2,3.2,2.2),'c','c','c'); px(c,ex+6,ey+1,'d'); px(c,ex+7,ey+1,'d'); px(c,ex+6,ey+2,'d'); px(c,ex+7,ey+2,'d')
    if kind=='oink':
        paint(c,ellipse(cx+5,cy+2,3.0,2.0),'8','7','8'); px(c,ex+5,ey+2,'d'); px(c,ex+7,ey+2,'d')
    if kind=='quack':
        paint(c,ellipse(cx+6,cy+2,4.0,1.8),'7','7','8')
        px(c,ex,ey-7,'3'); px(c,ex+1,ey-8,'3'); px(c,ex-1,ey-8,'3')
    if kind=='cub':
        paint(c,ellipse(cx+4,cy+2,3.0,2.2),'c','c','c'); px(c,ex+5,ey+1,'d'); px(c,ex+6,ey+1,'d'); px(c,ex+5,ey+2,'d')
    if kind=='goo':
        px(c,ex-1,ey-7,'7'); px(c,ex,ey-8,'7'); px(c,ex+1,ey-7,'7'); px(c,ex+1,ey-8,'7'); px(c,ex+2,ey-7,'7')
    # eyes (facing right)
    if hurt:
        for ox in (0,4):
            px(c,ex+ox,ey-2,'1'); px(c,ex+ox+1,ey-1,'1'); px(c,ex+ox,ey,'1'); px(c,ex+ox+1,ey-2,'1'); px(c,ex+ox,ey-1,'1'); px(c,ex+ox+1,ey,'1')
            c[ey-1][ex+ox]='1'
            px(c,ex+ox,ey-2,'1');px(c,ex+ox+1,ey,'1');px(c,ex+ox+1,ey-2,'1');px(c,ex+ox,ey,'1');px(c,ex+ox,ey-1,'1');px(c,ex+ox+1,ey-1,'1')
            # make an X: corners dark, center light
            px(c,ex+ox,ey-1,hcol[2]); px(c,ex+ox+1,ey-1,hcol[2]); px(c,ex+ox,ey-1,'1')
    else:
        for ox in (0,4):
            for yy in range(ey-2,ey+1):
                px(c,ex+ox,yy,'9'); px(c,ex+ox+1,yy,'9')
            px(c,ex+ox+1,ey-1,'a'); px(c,ex+ox+1,ey,'a'); px(c,ex+ox,ey,'a')
            px(c,ex+ox,ey-2,'e')
        if kind!='bugsy': px(c,ex-2,ey+1,'b')
    # mouths
    my=ey+3
    if kind=='goo':
        if hurt: px(c,ex+2,my,'1');px(c,ex+3,my,'b');px(c,ex+4,my,'1');px(c,ex+3,my+1,'1')
        else:
            paint(c,ellipse(cx+3.5,cy+3.5,1.8,1.6),'b','b','b'); px(c,ex+3,my,'d')
    elif kind in ('kit','hops'):
        px(c,ex+3,my-1,'b'); px(c,ex+4,my-1,'b'); px(c,ex+2,my,'1'); px(c,ex+5,my,'1')
        if kind=='hops': px(c,ex+3,my,'9'); px(c,ex+4,my,'9'); px(c,ex+3,my+1,'1'); px(c,ex+4,my+1,'1')
        if hurt: px(c,ex+3,my+1,'b'); px(c,ex+4,my+1,'b')
    elif kind=='bugsy':
        px(c,ex+2,my,'8'); px(c,ex+3,my,'8'); px(c,ex+4,my,'8')
        if hurt: px(c,ex+3,my+1,'8')
    elif kind in ('pup','cub'):
        px(c,ex+5,ey+3,'1'); px(c,ex+6,ey+3,'1')
        if hurt: px(c,ex+5,ey+4,'b'); px(c,ex+6,ey+4,'b')
    elif kind=='oink':
        if hurt: px(c,ex+4,ey+4,'1'); px(c,ex+5,ey+4,'1')
    elif kind=='quack':
        if hurt: px(c,ex+4,ey+2,'1'); px(c,ex+5,ey+2,'1'); px(c,ex+6,ey+2,'1')
    # floppy ears after head
    if kind=='pup':
        paint(c,ellipse(cx-5,cy+1,2.2,4.2),'7','7','8')
    return c

def tiles_of(c,ox,oy):
    """encode 8x8 tile at (ox,oy) as 16 words (SNES 4bpp)"""
    words=[]
    rows=[]
    for y in range(8):
        r=[]
        for x in range(8):
            k=c[oy+y][ox+x]
            r.append(0 if k=='.' else int(k,16))
        rows.append(r)
    for y in range(8):
        p0=p1=0
        for x in range(8):
            v=rows[y][x]; bit=7-x
            p0|=((v>>0)&1)<<bit; p1|=((v>>1)&1)<<bit
        words.append(p0|(p1<<8))
    for y in range(8):
        p2=p3=0
        for x in range(8):
            v=rows[y][x]; bit=7-x
            p2|=((v>>2)&1)<<bit; p3|=((v>>3)&1)<<bit
        words.append(p2|(p3<<8))
    return words

def hexcol(h):
    return tuple(int(h[i:i+2],16) for i in (1,3,5))

def encode_char(kind):
    """returns dict tile_index -> hex string (64 chars), for 12 cells in a 16-wide tile table (4 cells per row)"""
    out={}
    for pi,pn in enumerate(ORDER):
        c=draw(kind,pn)
        crow,ccol=pi//4,pi%4
        for ty in range(4):
            for tx in range(4):
                w=tiles_of(c,tx*8,ty*8)
                if any(w):
                    tile=crow*64+ty*16+ccol*4+tx
                    out[tile]=''.join('%04x'%v for v in w)
    return out

def show(c):
    for r in c: print(''.join(r))

if __name__=='__main__':
    if len(sys.argv)>1 and sys.argv[1]=='show':
        kind=sys.argv[2]; pn=sys.argv[3] if len(sys.argv)>3 else 'idle'
        show(draw(kind,pn)); sys.exit()
    for ci,kind in enumerate(KINDS):
        ch=CH[kind]; enc=encode_char(kind)
        lines=[f"-- {ch['name']}: generated sprite data (12 poses, 32x32, 4bpp)"]
        pal=', '.join('{%d,%d,%d}'%hexcol(h) for h in ch['pal'])
        lines.append(f"CHAR_PAL[{ci+1}] = {{ {pal} }}")
        lines.append(f"CHAR_NAME[{ci+1}] = \"{ch['name']}\"")
        lines.append(f"CHAR_TILES[{ci+1}] = {{")
        for t in sorted(enc): lines.append(f"  [{t}] = \"{enc[t]}\",")
        lines.append("}")
        src='\n'.join(lines)+'\n'
        open(f'char{ci+1}.lua','w').write(src)
        print(kind, len(enc), 'tiles', len(src), 'bytes')
