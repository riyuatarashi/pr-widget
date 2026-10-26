import sys, os
out = sys.argv[1]
CREAM, YEL, COR, TEAL, GRN = "#FFF1E4", "#FFB429", "#FF6A55", "#1BB3A0", "#2E6B4F"

def bell(x, y, s=1.0, rot=0, left=COR, right=TEAL, middle=YEL, clapper=GRN, swing=0):
    # Trois lobes comme la tulipe de référence : pétale central jaune, pétales latéraux corail et turquoise.
    return f'''<g transform="translate({x},{y}) rotate({rot}) scale({s})">
  <g transform="rotate({swing} 0 430)">
    <path d="M0,430 L0,486" stroke="{GRN}" stroke-width="20" stroke-linecap="round"/>
    <circle cx="0" cy="512" r="32" fill="{clapper}"/>
  </g>
  <path d="M0,6 C70,10 104,80 106,170 C110,270 150,336 200,398 C140,422 76,440 0,444 C-76,440 -140,422 -200,398 C-150,336 -110,270 -106,170 C-104,80 -70,10 0,6 Z" fill="{middle}"/>
  <path d="M0,0 C-70,4 -110,74 -114,164 C-118,264 -160,334 -222,394 C-164,414 -104,422 -46,414 C-34,300 -22,120 0,0 Z" fill="{left}"/>
  <path d="M0,0 C70,4 110,74 114,164 C118,264 160,334 222,394 C164,414 104,422 46,414 C34,300 22,120 0,0 Z" fill="{right}"/>
</g>'''

def stem(d, w=36):
    return f'<path d="{d}" fill="none" stroke="{GRN}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'

def leaf(d):
    return f'<path d="{d}" fill="{GRN}"/>'

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><rect width="1024" height="1024" fill="{CREAM}"/>{body}</svg>\n'

icons = {}

# A. Campanule : une fleur-cloche suspendue à une tige en arc.
icons["a-campanule"] = svg(
    stem("M250,900 C240,620 270,300 470,230 C560,198 600,240 600,296")
    + leaf("M256,660 C176,590 144,500 160,420 C246,450 290,550 256,660 Z")
    + bell(600, 296)
)

# B. Campanule qui tinte : la cloche se balance, le battant suit, deux ondes de chaque côté.
icons["b-tinte"] = svg(
    stem("M400,-40 C420,90 520,170 548,250 C554,268 556,286 556,300")
    + leaf("M452,150 C540,96 640,96 700,128 C640,190 540,200 452,150 Z")
    + bell(556, 300, 0.9, rot=-14, swing=20)
    + stem("M860,600 C886,640 892,690 874,740", 28).replace(GRN, COR)
    + stem("M928,560 C968,630 972,712 942,782", 28).replace(GRN, YEL)
    + stem("M296,640 C274,680 272,726 288,768", 28).replace(GRN, TEAL)
    + stem("M232,600 C198,662 196,734 222,796", 28).replace(GRN, YEL)
)

# C. Branche qui fleurit : la tige se sépare puis se rejoint (une PR qui merge), et la fleur éclot.
tulip = f'''<g transform="translate(512,318) scale(0.8) translate(-512,-420)">
<path d="M512,180 C596,240 638,356 630,462 C622,562 568,612 512,612 C456,612 402,562 394,462 C386,356 428,240 512,180 Z" fill="{YEL}"/>
<path d="M512,624 C394,624 308,548 302,420 C298,346 310,292 330,244 C420,290 504,394 532,548 Z" fill="{COR}"/>
<path d="M512,624 C630,624 716,548 722,420 C726,346 714,292 694,244 C604,290 520,394 492,548 Z" fill="{TEAL}"/>
</g>'''
icons["c-branche"] = svg(
    stem("M512,890 L512,470", 40)
    + stem("M512,856 C512,800 376,806 376,744 L376,624 C376,562 512,566 512,506")
    + leaf("M512,760 C560,676 660,652 736,672 C704,756 604,790 512,760 Z")
    + f'<circle cx="376" cy="684" r="42" fill="{CREAM}" stroke="{GRN}" stroke-width="24"/>'
    + tulip
)

# D. Duo : deux campanules sur la même tige, une grande et une petite.
icons["d-duo"] = svg(
    stem("M210,900 C200,620 280,330 500,262 C640,220 740,260 740,330")
    + stem("M470,272 C430,320 410,380 410,430", 28)
    + leaf("M214,700 C140,630 112,540 128,462 C212,494 252,594 214,700 Z")
    + bell(410, 430, 0.45, left=COR, right=YEL, middle=TEAL)
    + bell(740, 330, 0.7)
)

for name, content in icons.items():
    open(os.path.join(out, f"{name}.svg"), "w").write(content)
print(list(icons))
