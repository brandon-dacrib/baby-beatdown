import json, math, sys
KEYS = "123456789abcdef"
# placeholder palette (human baby) so the Studio preview looks sane
PAL = {"1":"#2a1a2e","2":"#c98a66","3":"#f0b48e","4":"#ffd9bd","5":"#f4f4f8","6":"#c2c6d8",
       "7":"#6a3a22","8":"#a0603a","9":"#ffffff","a":"#1a1020","b":"#f08aa0","c":"#f8f8ff","d":"#7a4a28","e":"#ffffff","f":"#ffe066"}

def canvas(w,h): return [['.']*w for _ in range(h)]

def capsule_mask(w,h,x0,y0,x1,y1,r):
    m=[[False]*w for _ in range(h)]
    dx,dy=x1-x0,y1-y0; L2=dx*dx+dy*dy
    for y in range(h):
        for x in range(w):
            px,py=x+0.5,y+0.5
            if L2==0: t=0
            else: t=max(0,min(1,((px-x0)*dx+(py-y0)*dy)/L2))
            cx,cy=x0+dx*t,y0+dy*t
            if (px-cx)**2+(py-cy)**2<=r*r: m[y][x]=True
    return m
def ellipse_mask(w,h,cx,cy,rx,ry):
    m=[[False]*w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            px,py=x+0.5,y+0.5
            if ((px-cx)/rx)**2+((py-cy)/ry)**2<=1: m[y][x]=True
    return m
def union(a,b):
    return [[a[y][x] or b[y][x] for x in range(len(a[0]))] for y in range(len(a))]
def paint(c,m,mid,dark,light,outline='1',shade=True):
    h=len(m); w=len(m[0])
    def inm(x,y): return 0<=x<w and 0<=y<h and m[y][x]
    for y in range(h):
        for x in range(w):
            if not m[y][x]: continue
            edge = not(inm(x-1,y) and inm(x+1,y) and inm(x,y-1) and inm(x,y+1))
            if edge: c[y][x]=outline; continue
            col=mid
            if shade:
                if not inm(x-2,y-1) or not inm(x-1,y-2): col=light
                elif not inm(x+2,y+1) or not inm(x+1,y+2): col=dark
            c[y][x]=col

# ---------- body ----------
# pose: neck, hip, back arm (elbow,hand), front arm, back leg (knee,foot), front leg, extra
def body(p):
    c=canvas(32,32)
    neck=p['neck']; hip=p['hip']
    sh=(neck[0],neck[1]+2)
    # back arm
    e,hd=p['barm']; paint(c,capsule_mask(32,32,sh[0]-2,sh[1],e[0],e[1],2.3),'3','2','4')
    paint(c,capsule_mask(32,32,e[0],e[1],hd[0],hd[1],2.0),'3','2','4')
    paint(c,ellipse_mask(32,32,hd[0],hd[1],2.6,2.4),'3','2','4')
    # back leg
    k,ft=p['bleg']; hj=(hip[0]-2,hip[1]+1)
    paint(c,capsule_mask(32,32,hj[0],hj[1],k[0],k[1],2.6),'3','2','4')
    paint(c,capsule_mask(32,32,k[0],k[1],ft[0],ft[1],2.3),'3','2','4')
    paint(c,ellipse_mask(32,32,ft[0]+0.5,ft[1]-0.5,2.8,1.8),'3','2','4')
    # torso
    tm=union(capsule_mask(32,32,neck[0],neck[1],hip[0],hip[1],5.0),ellipse_mask(32,32,(neck[0]+hip[0])/2+1,(neck[1]+hip[1])/2+2,6.0,5.0))
    paint(c,tm,'3','2','4')
    # diaper: lower part of torso
    dm=[[tm[y][x] and y>=hip[1]-4 for x in range(32)] for y in range(32)]
    dm=union(dm,ellipse_mask(32,32,hip[0],hip[1]+1,6.5,3.5))
    paint(c,dm,'5','6','5')
    # front leg
    k,ft=p['fleg']; hj=(hip[0]+2,hip[1]+1)
    paint(c,capsule_mask(32,32,hj[0],hj[1],k[0],k[1],2.6),'3','2','4')
    paint(c,capsule_mask(32,32,k[0],k[1],ft[0],ft[1],2.3),'3','2','4')
    paint(c,ellipse_mask(32,32,ft[0]+0.5,ft[1]-0.5,2.8,1.8),'3','2','4')
    # front arm
    e,hd=p['farm']; paint(c,capsule_mask(32,32,sh[0]+2,sh[1],e[0],e[1],2.3),'3','2','4')
    paint(c,capsule_mask(32,32,e[0],e[1],hd[0],hd[1],2.0),'3','2','4')
    paint(c,ellipse_mask(32,32,hd[0],hd[1],2.6,2.4),'3','2','4')
    # belly button
    bx,by=int((neck[0]+hip[0])/2)+1,int((neck[1]+hip[1])/2)+1
    if c[by][bx]=='3': c[by][bx]='2'
    return c

POSES = {
 'idle':  dict(neck=(14,9),hip=(14,21),barm=((9,14),(11,11)),farm=((19,14),(21,11)),bleg=((10,27),(9,31)),fleg=((18,27),(19,31))),
 'walk1': dict(neck=(14,9),hip=(14,21),barm=((9,14),(11,11)),farm=((19,14),(21,11)),bleg=((8,27),(6,31)),fleg=((20,27),(22,31))),
 'walk2': dict(neck=(14,9),hip=(14,21),barm=((9,14),(11,11)),farm=((19,14),(21,11)),bleg=((12,27),(13,31)),fleg=((16,27),(15,31))),
 'punch': dict(neck=(16,9),hip=(13,21),barm=((11,14),(13,11)),farm=((23,11),(29,11)),bleg=((9,27),(8,31)),fleg=((19,27),(20,31))),
 'kick':  dict(neck=(12,9),hip=(13,20),barm=((7,13),(9,10)),farm=((17,13),(19,10)),bleg=((9,27),(8,31)),fleg=((23,19),(29,17))),
 'crouch':dict(neck=(14,15),hip=(14,23),barm=((9,19),(11,17)),farm=((19,19),(21,17)),bleg=((8,28),(6,31)),fleg=((20,28),(22,31))),
 'jump':  dict(neck=(14,8),hip=(14,19),barm=((8,8),(9,4)),farm=((20,8),(19,4)),bleg=((11,25),(8,27)),fleg=((17,25),(20,27))),
 'hit':   dict(neck=(10,10),hip=(14,21),barm=((5,12),(3,9)),farm=((7,16),(5,13)),bleg=((10,27),(8,31)),fleg=((18,27),(20,31))),
 'block': dict(neck=(14,9),hip=(14,21),barm=((18,17),(19,12)),farm=((21,19),(20,14)),bleg=((10,27),(9,31)),fleg=((18,27),(19,31))),
 'ko':    dict(neck=(8,25),hip=(18,25),barm=((5,22),(3,20)),farm=((12,22),(11,19)),bleg=((24,29),(29,30)),fleg=((23,27),(28,27))),
 'super': dict(neck=(14,8),hip=(14,20),barm=((8,8),(7,3)),farm=((20,8),(21,3)),bleg=((8,27),(6,31)),fleg=((20,27),(22,31))),
}
ORDER=['idle','walk1','walk2','punch','kick','crouch','jump','hit','block','ko','super']

def keycell(size):
    c=canvas(size,size)
    for i,k in enumerate(KEYS): c[0][i]=k
    return c

def sheet(cells,size):
    rows=[]
    for y in range(size):
        rows.append(''.join(''.join(c[y]) for c in cells))
    return rows

body_cells=[keycell(32)]+[body(POSES[n]) for n in ORDER]
body_rows=sheet(body_cells,32)

# ---------- heads ----------
def head(kind,hurt):
    c=canvas(16,16)
    cx,cy,rx,ry=8,8.5,6.5,6.0
    if kind=='bunny': cy,ry=10,5.0
    # behind-head features
    if kind=='puppy':
        paint(c,ellipse_mask(16,16,2.5,9,2.0,4.0),'7','7','8'); paint(c,ellipse_mask(16,16,13.5,9,2.0,4.0),'7','7','8')
    if kind=='kitten':
        for (x0,y0) in [(2,0),(10,0)]:
            m=[[False]*16 for _ in range(16)]
            for y in range(6):
                for x in range(4):
                    if abs(x-1.5)<=y*0.6+0.4 and y0+y<16: m[y0+y][x0+x]=True
            paint(c,m,'3','2','4')
            for y in range(2,5):
                c[y0+y][x0+1]='b'; c[y0+y][x0+2]='b'
    if kind=='piglet' or kind=='bear':
        paint(c,ellipse_mask(16,16,3,3.5,2.6,2.6),'3','2','4'); paint(c,ellipse_mask(16,16,13,3.5,2.6,2.6),'3','2','4')
        c[3][3]='8'; c[3][13]='8'; c[4][3]='8'; c[4][12]='8'
    if kind=='bunny':
        paint(c,ellipse_mask(16,16,5,3.5,2.0,3.8),'3','2','4'); paint(c,ellipse_mask(16,16,11,3.5,2.0,3.8),'3','2','4')
        for y in range(1,6): c[y][5]='b'; c[y][11]='b'
    if kind=='bug':
        for x in (4,11):
            c[0][x]='7'; c[1][x]='7'; c[2][x+ (1 if x==4 else -1)]='1'
    # head
    skin=('3','2','4')
    if kind=='bug': skin=('7','7','8')
    paint(c,ellipse_mask(16,16,cx,cy,rx,ry),*skin)
    # eyes
    ey=int(cy)-1
    if hurt:
        for x in (4,5,6): c[ey-1][x] = '1' if x!=5 else '1'
        c[ey][5]='1'; c[ey-1][4]='1'; c[ey-1][6]='1'; c[ey+1][4]='1'; c[ey+1][6]='1'
        c[ey][10]='1'; c[ey-1][9]='1'; c[ey-1][11]='1'; c[ey+1][9]='1'; c[ey+1][11]='1'
        c[ey-1][5]='4' if kind!='bug' else '8'; c[ey-1][10]='4' if kind!='bug' else '8'
    else:
        big = kind=='bug'
        for ex in (4,10):
            for yy in range(ey-1,ey+2):
                c[yy][ex]='9'; c[yy][ex+1]='9'
            c[ey][ex+1]='a'; c[ey+1][ex]='a'; c[ey+1][ex+1]='a'
            c[ey-1][ex]='e'
    # cheeks
    if not hurt and kind!='bug':
        c[ey+2][2]='b'; c[ey+2][13]='b'
    # mouth / features
    my=ey+3
    if kind=='human':
        if hurt:
            c[my][6]='1';c[my][7]='b';c[my][8]='b';c[my][9]='1';c[my+1][7]='1';c[my+1][8]='1'
        else:
            c[my][7]='b';c[my][8]='b';c[my-1][7]='1';c[my-1][8]='1';c[my][6]='1';c[my][9]='1'; c[my+1][7]='1'; c[my+1][8]='1'
        c[1][7]='7';c[0][8]='7';c[1][8]='7';c[2][9]='7'
    elif kind=='puppy':
        c[my-1][7]='a';c[my-1][8]='a';c[my][7]='a';c[my][8]='a'
        c[my+1][6]='1';c[my+1][9]='1'
        if hurt: c[my+1][7]='b';c[my+1][8]='b'
    elif kind=='kitten':
        c[my-1][7]='b';c[my-1][8]='b';c[my][7]='1';c[my][8]='1'
        c[my][6]='1';c[my][9]='1'; c[my-1][4]='1';c[my-1][11]='1'; c[my][3]='1';c[my][12]='1'
        if hurt: c[my+1][7]='b';c[my+1][8]='b'
    elif kind=='piglet':
        paint(c,ellipse_mask(16,16,8,my,3.2,1.8),'8','8','8')
        c[my][6]='2';c[my][9]='2'
        if hurt: c[my+2][7]='1';c[my+2][8]='1'
    elif kind=='duck':
        paint(c,ellipse_mask(16,16,8,my,3.8,1.6),'7','7','8')
        if hurt: c[my+1][7]='1';c[my+1][8]='1'
        c[1][7]='7';c[0][8]='7';c[2][8]='7'
    elif kind=='bear':
        paint(c,ellipse_mask(16,16,8,my,3.0,1.8),'4','4','4')
        c[my-1][7]='a';c[my-1][8]='a';c[my][7]='a'
        if hurt: c[my+1][7]='1';c[my+1][8]='1'
    elif kind=='bunny':
        c[my-1][7]='b';c[my-1][8]='b'; c[my][7]='9';c[my][8]='9'; c[my][6]='1';c[my][9]='1'
        if hurt: c[my+1][7]='1';c[my+1][8]='1'
    elif kind=='bug':
        c[my][7]='1';c[my][8]='1'
        if hurt: c[my-1][7]='b'; c[my-1][8]='b'; c[my][6]='1'; c[my][9]='1'
    return c

KINDS=['human','puppy','kitten','piglet','duck','bear','bunny','bug']
head_cells=[keycell(16)]
for k in KINDS:
    head_cells.append(head(k,False)); head_cells.append(head(k,True))
head_rows=sheet(head_cells,16)

# ---------- fx (projectiles) 16x16, indices 1,c,d,e ----------
FX = {
'human': [ # diaper
"................",
"................",
"....11....11....",
"...1cc1..1cc1...",
"..1ccdd11ddcc1..",
"..1cddddddddc1..",
"...1dddddddd1...",
"...1dddddddd1...",
"....1dddddd1....",
"....1dddddd1....",
".....1dddd1.....",
".....1cccc1.....",
"......1cc1......",
".......11.......",
"................",
"................"],
'puppy': [ # bottle
"................",
".....1111.......",
"....1dddd1......",
"....1dddd1......",
".....1dd1.......",
"....11cc11......",
"...1cccccc1.....",
"...1ceeecc1.....",
"...1ceeecc1.....",
"...1cccccc1.....",
"...1cccccc1.....",
"...1ceeecc1.....",
"...1cccccc1.....",
"....111111......",
"................",
"................"],
'kitten': [ # rattle
"......111.......",
".....1ccc1......",
"....1cceec1.....",
"....1ceeec1.....",
"....1ccccc1.....",
".....1ccc1......",
"......1d1.......",
"......1d1.......",
"......1d1.......",
"......1d1.......",
"......1d1.......",
".....1ddd1......",
".....1ddd1......",
"......111.......",
"................",
"................"],
'piglet': [ # pacifier
"................",
"................",
".....1111.......",
"....1cccc1......",
"...1cceecc1.....",
"...1cccccc1.....",
"..11111111111...",
"..1ddddddddd1...",
"..1ddddddddd1...",
"..11111111111...",
".....1ddd1......",
"....1d1d1d1.....",
"....1dd.dd1.....",
".....11111......",
"................",
"................"],
'duck': [ # bubble
"................",
".....11111......",
"...11ccccc11....",
"..1cceeccccc1...",
".1cceecccccccc1.",
".1ceccccccccc1..",
"1ccccccccccccd1.",
"1cccccccccccdd1.",
"1cccccccccccdd1.",
"1ccccccccccddd1.",
".1cccccccccdd1..",
".1ccccccccddd1..",
"..1ccccccddd1...",
"...11cddddd1....",
".....11111......",
"................"],
'bear': [ # shockwave / dust
"................",
"................",
"................",
"......11........",
".....1cc1..11...",
"....1cddc11cc1..",
"...1cdddcccddc1.",
"..1cdddddddddc1.",
".1cdddddddddddc1",
"1cddddddddddddc1",
"1ddddddddddddd1.",
"1ddddddddddddd1.",
".11111111111111.",
"................",
"................",
"................"],
'bunny': [ # chomp teeth
"................",
"................",
"..111111111111..",
".1cccccccccccc1.",
".1cccccccccccc1.",
".1c1cc1cc1cc1c1.",
".1c1cc1cc1cc1c1.",
"..1dddddddddd1..",
"..1dddddddddd1..",
".1c1cc1cc1cc1c1.",
".1c1cc1cc1cc1c1.",
".1cccccccccccc1.",
".1cccccccccccc1.",
"..111111111111..",
"................",
"................"],
'bug': [ # spit blob
"................",
"................",
"......11........",
"....11cc1.......",
"...1ccddd1..11..",
"..1cdddddd11dd1.",
"..1cdddddddddd1.",
"..1ddddddddddd1.",
"...1ddddddddd1..",
"....1ddd1ddd1...",
".....111.111....",
"................",
"................",
"................",
"................",
"................"],
}
fx_cells=[keycell(16)]+[[list(r) for r in FX[k]] for k in KINDS]
for k in KINDS:
    assert len(FX[k])==16 and all(len(r)==16 for r in FX[k]), k
fx_rows=sheet(fx_cells,16)

# ---------- font (2bpp) ----------
F = {
'A':["01110","10001","10001","11111","10001","10001","10001"],
'B':["11110","10001","10001","11110","10001","10001","11110"],
'C':["01110","10001","10000","10000","10000","10001","01110"],
'D':["11110","10001","10001","10001","10001","10001","11110"],
'E':["11111","10000","10000","11110","10000","10000","11111"],
'F':["11111","10000","10000","11110","10000","10000","10000"],
'G':["01110","10001","10000","10111","10001","10001","01111"],
'H':["10001","10001","10001","11111","10001","10001","10001"],
'I':["01110","00100","00100","00100","00100","00100","01110"],
'J':["00111","00010","00010","00010","00010","10010","01100"],
'K':["10001","10010","10100","11000","10100","10010","10001"],
'L':["10000","10000","10000","10000","10000","10000","11111"],
'M':["10001","11011","10101","10101","10001","10001","10001"],
'N':["10001","11001","10101","10011","10001","10001","10001"],
'O':["01110","10001","10001","10001","10001","10001","01110"],
'P':["11110","10001","10001","11110","10000","10000","10000"],
'Q':["01110","10001","10001","10001","10101","10010","01101"],
'R':["11110","10001","10001","11110","10100","10010","10001"],
'S':["01111","10000","10000","01110","00001","00001","11110"],
'T':["11111","00100","00100","00100","00100","00100","00100"],
'U':["10001","10001","10001","10001","10001","10001","01110"],
'V':["10001","10001","10001","10001","10001","01010","00100"],
'W':["10001","10001","10001","10101","10101","10101","01010"],
'X':["10001","10001","01010","00100","01010","10001","10001"],
'Y':["10001","10001","01010","00100","00100","00100","00100"],
'Z':["11111","00001","00010","00100","01000","10000","11111"],
'0':["01110","10001","10011","10101","11001","10001","01110"],
'1':["00100","01100","00100","00100","00100","00100","01110"],
'2':["01110","10001","00001","00010","00100","01000","11111"],
'3':["11110","00001","00001","01110","00001","00001","11110"],
'4':["00010","00110","01010","10010","11111","00010","00010"],
'5':["11111","10000","11110","00001","00001","10001","01110"],
'6':["00110","01000","10000","11110","10001","10001","01110"],
'7':["11111","00001","00010","00100","01000","01000","01000"],
'8':["01110","10001","10001","01110","10001","10001","01110"],
'9':["01110","10001","10001","01111","00001","00010","01100"],
'!':["00100","00100","00100","00100","00100","00000","00100"],
'.':["00000","00000","00000","00000","00000","00000","00100"],
'-':["00000","00000","00000","11111","00000","00000","00000"],
':':["00000","00100","00000","00000","00000","00100","00000"],
'>':["01000","00100","00010","00001","00010","00100","01000"],
'<':["00010","00100","01000","10000","01000","00100","00010"],
}
FONT_ORDER=" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!.-:><"
font_cells=[]
for ch in FONT_ORDER:
    c=canvas(8,8)
    if ch!=' ':
        g=F[ch]
        for y in range(7):
            for x in range(5):
                if g[y][x]=='1':
                    c[y][x+1]='1'
        # drop shadow in index 3
        for y in range(7):
            for x in range(5):
                if g[y][x]=='1':
                    if c[y+1][x+2]=='.': c[y+1][x+2]='3'
    font_cells.append(c)
# special tiles: bar full(2), bar empty(3), super full(1), super empty(3), bar cap
def tile(rows): return [list(r) for r in rows]
font_cells.append(tile(["33333333","32222222","32222222","32222222","32222222","32222222","32222222","33333333"]))  # 43 bar full
font_cells.append(tile(["33333333","3.......","3.......","3.......","3.......","3.......","3.......","33333333"]))  # 44 bar empty
font_cells.append(tile(["........","33333333","31111111","31111111","31111111","33333333","........","........"]))  # 45 super full
font_cells.append(tile(["........","33333333","3.......","3.......","3.......","33333333","........","........"]))  # 46 super empty
font_cells.append(tile(["33333333","32222222","32222222","32222222","32222222","32222222","32222222","33333333"]))  # 47 (dup for safety)
font_rows=sheet(font_cells,8)
FONT_PAL={"1":"#ffffff","2":"#ffd23c","3":"#2a2a5a"}

# ---------- stage tiles (4bpp) ----------
ST_PAL={"w":"#dcefff","s":"#b8d8f8","p":"#ffd6e8","q":"#ffb3d1","b":"#7a9ccf","k":"#2f3f6e","g":"#9edc8e","h":"#6fbf62","t":"#f0e0b0","u":"#e0c890","v":"#c8a870","r":"#ff6f6f","y":"#ffe070","o":"#ff9f3c"}
ST = {
'wall':   ["wwwwwwww"]*8,
'wallstar':["wwwwwwww","wwwpwwww","wwpqpwww","wpqqqpww","wwpqpwww","wwwpwwww","wwwwwwww","wwwwwwww"],
'walldot':["wwwwwwww","wwwwwwww","wwwwwsww","wwwwsssw","wwwwwsww","wwwwwwww","wwwwwwww","wwwwwwww"],
'base':   ["ssssssss","bbbbbbbb","kkkkkkkk","bbbbbbbb","bbbbbbbb","bbbbbbbb","kkkkkkkk","kkkkkkkk"],
'floor':  ["gggggggg","hghghghg","gggggggg","ghghghgh","gggggggg","hghghghg","gggggggg","ghghghgh"],
'floor2': ["tttttttt","tuuuuuut","tuttttut","tutuutut","tutuutut","tuttttut","tuuuuuut","tttttttt"],
'blockA1':["rrrrrrrr","ryyyyyyy","ryyyyyyy","ryyyryyy","ryyryryy","ryyrrryy","ryyryryy","ryyryryy"],
'blockA2':["rrrrrrrr","yyyyyyyr","yyyyyyyr","yyyyyyyr","yyyyyyyr","yyyyyyyr","yyyyyyyr","yyyyyyyr"],
'blockA3':["ryyyyyyy","ryyyyyyy","ryyyyyyy","ryyyyyyy","ryyyyyyy","ryyyyyyy","ryyyyyyy","rrrrrrrr"],
'blockA4':["yyyyyyyr","yyyyyyyr","yyyyyyyr","yyyyyyyr","yyyyyyyr","yyyyyyyr","yyyyyyyr","rrrrrrrr"],
'ball1':  ["wwwwwwww","wwwooooo","wwoooooo","woooorrr","woooorrr","wooorrrr","wooorrrr","wooorrrr"],
'ball2':  ["wwwwwwww","ooooowww","oooooowww"[:8],"rrrooooo","rrrooooo","rrrrooow","rrrrooow","rrrrooow"],
'ball3':  ["wooorrrr","wooorrrr","wooorrrr","wwoorrrr","wwoorrrr","wwwoorrw","wwwwoorw","wwwwwwww"],
'ball4':  ["rrrrooow","rrrrooow","rrrrooow","rrrrooww","rrrrooww","wrrooowww"[:8],"wrooowww","wwwwwwww"],
'crib':   ["wwkwwwkw","wwkwwwkw","wwkwwwkw","wwkwwwkw","wwkwwwkw","wwkwwwkw","wwkwwwkw","wwkwwwkw"],
'cribtop':["kkkkkkkk","kkkkkkkk","wwkwwwkw","wwkwwwkw","wwkwwwkw","wwkwwwkw","wwkwwwkw","wwkwwwkw"],
}
ST_ORDER=['wall','wallstar','walldot','base','floor','floor2','blockA1','blockA2','blockA3','blockA4','ball1','ball2','ball3','ball4','crib','cribtop']
for n in ST_ORDER: assert len(ST[n])==8 and all(len(r)==8 for r in ST[n]), n
st_rows=sheet([tile(ST[n]) for n in ST_ORDER],8)

out={'body':{'grid':body_rows,'palette':PAL},'heads':{'grid':head_rows,'palette':PAL},'fx':{'grid':fx_rows,'palette':PAL},
     'font':{'grid':font_rows,'palette':FONT_PAL},'stage':{'grid':st_rows,'palette':ST_PAL}}
for k,v in out.items():
    json.dump(v,open(f'/private/tmp/claude-501/-Users-brandon-git-my-infra/84d82ba6-dd92-4fee-bde9-a487b101cb98/scratchpad/bb/{k}.json','w'))
# preview
def show(rows):
    for r in rows: print(r)
if len(sys.argv)>1: show(out[sys.argv[1]]['grid'])
# head anchors for lua
print("NECK = {" + ", ".join(f"{{{POSES[n]['neck'][0]},{POSES[n]['neck'][1]}}}" for n in ORDER) + "}")
