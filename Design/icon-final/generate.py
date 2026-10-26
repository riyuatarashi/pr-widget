"""Icône PR Radar : la tige est une branche git (fork, commit, merge) qui se courbe et porte une campanule.

    python3 generate.py <dossier de sortie>   →   un SVG par palette
"""
import os
import sys

PALETTES = {
    # Les campanules sauvages sont bleu-violet : indigo, lavande, cœur bleu ciel, pistil doré.
    "bleuet": dict(bg="#FFF3E6", left="#4F5BD5", right="#8E7CF0", middle="#BFE3FF", clapper="#FFC857", stem="#55703A"),
    "prune": dict(bg="#FFF1EA", left="#8E3B6B", right="#E7A0C4", middle="#FFD3B6", clapper="#8E3B6B", stem="#2F4858"),
    "mimosa": dict(bg="#FBF3E4", left="#264653", right="#7A9E7E", middle="#F4D35E", clapper="#F4D35E", stem="#6B4F3A"),
}


def bell(x, y, s, p):
    return f'''<g transform="translate({x},{y}) scale({s})">
  <path d="M0,430 L0,486" stroke="{p['stem']}" stroke-width="22" stroke-linecap="round"/>
  <circle cx="0" cy="512" r="34" fill="{p['clapper']}"/>
  <path d="M0,6 C70,10 104,80 106,170 C110,270 150,336 200,398 C140,422 76,440 0,444 C-76,440 -140,422 -200,398 C-150,336 -110,270 -106,170 C-104,80 -70,10 0,6 Z" fill="{p['middle']}"/>
  <path d="M0,0 C-70,4 -110,74 -114,164 C-118,264 -160,334 -222,394 C-164,414 -104,422 -46,414 C-34,300 -22,120 0,0 Z" fill="{p['left']}"/>
  <path d="M0,0 C70,4 110,74 114,164 C118,264 160,334 222,394 C164,414 104,422 46,414 C34,300 22,120 0,0 Z" fill="{p['right']}"/>
</g>'''


def icon(p):
    stroke = f'fill="none" stroke="{p["stem"]}" stroke-linecap="round" stroke-linejoin="round"'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<rect width="1024" height="1024" fill="{p['bg']}"/>
<g transform="translate(-40,0)">
  <path d="M360,900 C352,760 350,600 372,470 C400,320 480,236 580,226 C650,220 700,262 700,316" {stroke} stroke-width="40"/>
  <path d="M357,852 C357,794 240,800 240,738 L240,628 C240,566 362,572 367,512" {stroke} stroke-width="34"/>
  <circle cx="240" cy="683" r="40" fill="{p['bg']}" stroke="{p['stem']}" stroke-width="24"/>
  <path d="M357,792 C404,716 488,698 560,714 C530,790 446,818 357,792 Z" fill="{p['stem']}"/>
  {bell(700, 316, 0.86, p)}
</g>
</svg>
'''


if __name__ == "__main__":
    out = sys.argv[1]
    for name, palette in PALETTES.items():
        with open(os.path.join(out, f"pr-radar-{name}.svg"), "w") as f:
            f.write(icon(palette))
