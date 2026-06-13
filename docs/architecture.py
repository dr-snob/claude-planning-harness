#!/usr/bin/env python3
# Portrait, pastel, icon-driven flow infographic for planning-harness.
import html

W = 1200
PAD = 60
SLATE   = "#3A3F57"
MUTE    = "#727aa0"
WHITE   = "#FFFFFF"

# cool pastel section themes: (soft fill, accent, deep)
SKY   = ("#DCEBFB", "#3B82F6", "#1D4ED8")
LILAC = ("#E7DEFB", "#8B5CF6", "#6D28D9")
MINT  = ("#D1F0E6", "#12B886", "#0B7C5B")
INDIGO= ("#DFE3FE", "#6366F1", "#4338CA")
ROSE  = ("#FBD2E4", "#EC4899", "#BE185D")   # blocks (cool pink)

S=[]
def o(x): S.append(x)
def esc(t): return html.escape(t, quote=True)

def wrap(t,n):
    out, cur = [], ""
    for w in t.split():
        if len(cur)+len(w)+(1 if cur else 0)<=n: cur=(cur+" "+w) if cur else w
        else: out.append(cur); cur=w
    if cur: out.append(cur)
    return out

# ---------- icon glyphs (drawn inside a r=20 badge at cx,cy) ----------
def badge(cx,cy,fill,glyph):
    o(f'<circle cx="{cx}" cy="{cy}" r="21" fill="{fill}"/>')
    o(glyph(cx,cy))

def ic_key(cx,cy):
    s=f'<rect x="{cx-12}" y="{cy-8}" width="24" height="16" rx="3" fill="none" stroke="#fff" stroke-width="2"/>'
    for dx in (-7,-1,5):
        for dy in (-3,3):
            s+=f'<circle cx="{cx+dx}" cy="{cy+dy}" r="1.4" fill="#fff"/>'
    return s
def ic_doc(cx,cy):
    return (f'<path d="M{cx-9},{cy-12} h12 l6,6 v18 h-18 z" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/>'
            f'<path d="M{cx+3},{cy-12} v6 h6" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/>'
            f'<line x1="{cx-5}" y1="{cy+1}" x2="{cx+5}" y2="{cy+1}" stroke="#fff" stroke-width="2"/>'
            f'<line x1="{cx-5}" y1="{cy+6}" x2="{cx+3}" y2="{cy+6}" stroke="#fff" stroke-width="2"/>')
def ic_play(cx,cy):
    return f'<path d="M{cx-7},{cy-9} L{cx+9},{cy} L{cx-7},{cy+9} Z" fill="#fff"/>'
def ic_check(cx,cy):
    return f'<path d="M{cx-9},{cy} l6,7 l12,-14" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>'
def ic_pen(cx,cy):
    return (f'<path d="M{cx-10},{cy+10} l3,-9 l13,-13 l6,6 l-13,13 z" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/>'
            f'<line x1="{cx-10}" y1="{cy+10}" x2="{cx-5}" y2="{cy+5}" stroke="#fff" stroke-width="2"/>')
def ic_stop(cx,cy):
    return (f'<circle cx="{cx}" cy="{cy}" r="11" fill="none" stroke="#fff" stroke-width="2.4"/>'
            f'<line x1="{cx-7}" y1="{cy-7}" x2="{cx+7}" y2="{cy+7}" stroke="#fff" stroke-width="2.4"/>')
def ic_loop(cx,cy):
    return (f'<path d="M{cx+10},{cy-3} A11,11 0 1 1 {cx-2},{cy-11}" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/>'
            f'<path d="M{cx-6},{cy-13} l4,2 l-1,5" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
def ic_box(cx,cy):
    return (f'<path d="M{cx-11},{cy-5} l11,-6 l11,6 v12 l-11,6 l-11,-6 z" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/>'
            f'<path d="M{cx-11},{cy-5} l11,6 l11,-6 M{cx},{cy+1} v12" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/>')
def ic_commit(cx,cy):
    return (f'<line x1="{cx-12}" y1="{cy}" x2="{cx+12}" y2="{cy}" stroke="#fff" stroke-width="2.2"/>'
            f'<circle cx="{cx}" cy="{cy}" r="5" fill="none" stroke="#fff" stroke-width="2.2"/>')

# ---------- a "chip" : rounded card with icon badge, title, sub ----------
def chip(x,y,w,h,fill,border,icon,iconcol,title,sub,title_col=None,sub_col=None):
    title_col = title_col or SLATE
    sub_col = sub_col or MUTE
    o(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" fill="{fill}" stroke="{border}" stroke-width="1.5" filter="url(#sh)"/>')
    if icon:
        badge(x+34, y+h/2, iconcol, icon)
        tx = x+64
    else:
        tx = x+22
    if sub:
        o(f'<text x="{tx}" y="{y+h/2-4}" font-size="19" font-weight="700" fill="{title_col}">{esc(title)}</text>')
        o(f'<text x="{tx}" y="{y+h/2+18}" font-size="14.5" fill="{sub_col}">{esc(sub)}</text>')
    else:
        o(f'<text x="{tx}" y="{y+h/2+6}" font-size="19" font-weight="700" fill="{title_col}">{esc(title)}</text>')

def arrow_down(x, y1, y2, col, label=None):
    o(f'<line x1="{x}" y1="{y1}" x2="{x}" y2="{y2-10}" stroke="{col}" stroke-width="2.6"/>')
    o(f'<path d="M{x-6},{y2-11} L{x},{y2-1} L{x+6},{y2-11} Z" fill="{col}"/>')
    if label:
        o(f'<rect x="{x+10}" y="{(y1+y2)/2-12}" width="{10+len(label)*7.2}" height="22" rx="11" fill="#fff" stroke="{col}" stroke-width="1"/>')
        o(f'<text x="{x+15}" y="{(y1+y2)/2+3.5}" font-size="13" font-weight="600" fill="{col}">{esc(label)}</text>')

def arrow_right(x1, x2, y, col, label=None):
    o(f'<line x1="{x1}" y1="{y}" x2="{x2-10}" y2="{y}" stroke="{col}" stroke-width="2.6"/>')
    o(f'<path d="M{x2-11},{y-6} L{x2-1},{y} L{x2-11},{y+6} Z" fill="{col}"/>')
    if label:
        o(f'<text x="{(x1+x2)/2}" y="{y-9}" font-size="13" font-weight="600" fill="{col}" text-anchor="middle">{esc(label)}</text>')

# =========================================================================
# build
# =========================================================================
o('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="__H__" viewBox="0 0 %d __H__" font-family="Verdana, Geneva, sans-serif">' % (W, W))
o('<defs>')
o('<linearGradient id="bg" x1="0" y1="0" x2="0.4" y2="1">'
  '<stop offset="0" stop-color="#EEF1FE"/><stop offset="0.55" stop-color="#EAF2FB"/><stop offset="1" stop-color="#E7F7F3"/></linearGradient>')
o('<linearGradient id="hdr" x1="0" y1="0" x2="1" y2="1">'
  '<stop offset="0" stop-color="#8B7CF6"/><stop offset="0.5" stop-color="#6CA8F4"/><stop offset="1" stop-color="#4FD0C9"/></linearGradient>')
o('<filter id="sh" x="-20%" y="-20%" width="140%" height="160%">'
  '<feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#3A3F57" flood-opacity="0.13"/></filter>')
o('<filter id="shx" x="-40%" y="-40%" width="180%" height="200%">'
  '<feDropShadow dx="0" dy="8" stdDeviation="14" flood-color="#3A3F57" flood-opacity="0.18"/></filter>')
o('</defs>')

o(f'<rect width="{W}" height="__H__" fill="url(#bg)"/>')
# decorative soft blobs (eye-catching, low opacity)
for (bx,by,br,bc,op) in [(60,520,210,"#8B5CF6",0.07),(1010,980,260,"#12B886",0.07),
                         (90,1640,230,"#3B82F6",0.06),(1000,2160,240,"#6366F1",0.07),
                         (980,360,150,"#EC4899",0.06)]:
    o(f'<circle cx="{bx}" cy="{by}" r="{br}" fill="{bc}" opacity="{op}"/>')

# ---------------- header ----------------
o(f'<rect x="{PAD}" y="44" width="{W-2*PAD}" height="168" rx="26" fill="url(#hdr)" filter="url(#shx)"/>')
o(f'<text x="{W/2}" y="118" font-size="46" font-weight="800" fill="#fff" text-anchor="middle" letter-spacing="0.5">planning-harness</text>')
o(f'<text x="{W/2}" y="156" font-size="19" fill="#EAF0FF" text-anchor="middle">A Claude Code plugin — how 13 hooks wire into your session</text>')
o(f'<rect x="{W/2-150}" y="172" width="300" height="28" rx="14" fill="#ffffff" opacity="0.22"/>')
o(f'<text x="{W/2}" y="191" font-size="14" font-weight="700" fill="#fff" text-anchor="middle" letter-spacing="2">FOLLOW THE ARROWS  ·  TOP TO BOTTOM</text>')

# ---------------- spine ----------------
spine_x = 96
y0 = 268
o(f'<line x1="{spine_x}" y1="{y0}" x2="{spine_x}" y2="__SY2__" stroke="#C9D0EC" stroke-width="4"/>')

# ---------------- a section helper ----------------
content_x = 150
content_w = W - PAD - content_x   # right edge
def station(num, cy, theme):
    o(f'<circle cx="{spine_x}" cy="{cy}" r="30" fill="{theme[1]}" filter="url(#sh)"/>')
    o(f'<circle cx="{spine_x}" cy="{cy}" r="30" fill="none" stroke="#fff" stroke-width="3"/>')
    o(f'<text x="{spine_x}" y="{cy+9}" font-size="26" font-weight="800" fill="#fff" text-anchor="middle">{num}</text>')
def heading(y, theme, title, sub):
    o(f'<text x="{content_x}" y="{y}" font-size="25" font-weight="800" fill="{theme[2]}">{esc(title)}</text>')
    o(f'<text x="{content_x}" y="{y+26}" font-size="16" fill="{MUTE}">{esc(sub)}</text>')

CH = 64  # chip height

# ============ STORY 1 — CONTINUITY (sky) ============
y = y0+20
station("1", y+8, SKY)
heading(y, SKY, "Session continuity — the loop", "Your context survives across sessions, automatically.")
cy = y+58
cw = content_w
# row A
chip(content_x, cy, 300, CH, "#fff", SKY[1], ic_key, SKY[1], '"wrap up"', "what you type")
arrow_right(content_x+300, content_x+300+78, cy+CH/2, SKY[1], "fires")
chip(content_x+378, cy, content_x+cw-(content_x+378), CH, SKY[0], SKY[1], None, SKY[1], "end-session-handoff", "writes a full handoff file")
arrow_down(content_x+150, cy+CH, cy+CH+58, SKY[1], "writes")
cy2 = cy+CH+58
chip(content_x, cy2, 470, CH, "#fff", SKY[1], ic_doc, SKY[1], ".planning/resume-next-session.md", "the saved context")
# loop arrow from doc down to next-session row
arrow_down(content_x+150, cy2+CH, cy2+CH+58, SKY[2], "next session reads it back")
cy3 = cy2+CH+58
chip(content_x, cy3, 300, CH, "#fff", SKY[1], ic_play, SKY[1], "new session", "auto-starts")
arrow_right(content_x+300, content_x+300+78, cy3+CH/2, SKY[1], "loads")
chip(content_x+378, cy3, content_x+cw-(content_x+378), CH, SKY[0], SKY[1], ic_check, SKY[2], "auto-load-resume-notes", "you resume with full context — no re-explaining")

# ============ STORY 2 — SCOPE (lilac) ============
y = cy3+CH+96
station("2", y+8, LILAC)
heading(y, LILAC, "Change-scope discipline — a guard", "You only edit what you declared. Drift gets caught before it ships.")
cy = y+58
chip(content_x, cy, 300, CH, "#fff", LILAC[1], ic_pen, LILAC[1], "you edit a file", "any code change")
arrow_right(content_x+300, content_x+300+86, cy+CH/2, LILAC[1], "intercepts")
chip(content_x+386, cy, content_x+cw-(content_x+386), CH, LILAC[0], LILAC[1], None, LILAC[1], "change-scope-pre-edit-gate", "checks it against .planning/scope.md")
arrow_down(content_x+150, cy+CH, cy+CH+58, ROSE[1], "if the file isn't in scope")
cyb = cy+CH+58
chip(content_x, cyb, 300, CH, ROSE[0], ROSE[1], ic_stop, ROSE[1], "BLOCKED", "edit is stopped", title_col=ROSE[2])
arrow_right(content_x+300, content_x+300+78, cyb+CH/2, ROSE[1], "you fix it")
chip(content_x+378, cyb, content_x+cw-(content_x+378), CH, "#fff", LILAC[1], ic_doc, LILAC[1], "add it to scope.md  →  edit proceeds", "(or revert the stray change)")
# secondary line
cyc = cyb+CH+44
chip(content_x, cyc, 280, CH-8, "#fff", LILAC[1], ic_commit, LILAC[1], "git commit", "before it lands")
arrow_right(content_x+280, content_x+280+74, cyc+(CH-8)/2, LILAC[1], "nudges")
chip(content_x+354, cyc, content_x+cw-(content_x+354), CH-8, INDIGO[0], LILAC[1], None, LILAC[1], "change-scope-reminder", "audit the diff hunk-by-hunk, drop unrelated drift")

# ============ STORY 3 — PLAN (mint) ============
RX = content_x + cw   # right edge for content (=1020)
y = cyc+CH+88
station("3", y+8, MINT)
heading(y, MINT, "Plan tracking & completion", "“Done” has to match the plan. The final sign-off stays yours.")
cy = y+58
chip(content_x, cy, RX-content_x, CH, MINT[0], MINT[1], ic_doc, MINT[1], ".planning/plan.md   —   [ ] N.M steps   ·   [ ] 99.0", "the live checklist every guard reads")
# claim row:  "it's done" -> completion-claim-guard -> BLOCKED
cy += CH+44
chip(content_x, cy, 230, CH, "#fff", MINT[1], ic_key, MINT[1], '"it\'s done"', "you claim it")
arrow_right(content_x+230, content_x+300, cy+CH/2, MINT[1], "checks")
chip(content_x+300, cy, 360, CH, "#fff", MINT[1], None, MINT[1], "completion-claim-guard", "")
arrow_right(content_x+660, content_x+730, cy+CH/2, ROSE[1], "if open")
chip(content_x+730, cy, RX-(content_x+730), CH, ROSE[0], ROSE[1], ic_stop, ROSE[1], "BLOCKED", "tick / fix", title_col=ROSE[2])
# flip row: flip 99.0 -> flip-guard (human-only)
cy += CH+44
chip(content_x, cy, 300, CH, "#fff", MINT[1], ic_pen, MINT[1], "flip the 99.0 box", "mark plan complete")
arrow_right(content_x+300, content_x+390, cy+CH/2, MINT[2], "human-only")
chip(content_x+390, cy, RX-(content_x+390), CH, "#fff", MINT[1], None, MINT[1], "plan-complete-flip-guard", "only you may flip it — never the agent")
# archive row: once OK -> detector -> archive/
cy += CH+44
chip(content_x, cy, 250, CH, "#fff", MINT[1], ic_check, MINT[2], "once you OK it", "")
arrow_right(content_x+250, content_x+320, cy+CH/2, MINT[1], "then")
chip(content_x+320, cy, 360, CH, "#fff", MINT[1], None, MINT[1], "plan-completion-detector", "")
arrow_right(content_x+680, content_x+750, cy+CH/2, MINT[2], "")
chip(content_x+750, cy, RX-(content_x+750), CH, MINT[0], MINT[1], ic_box, MINT[1], "archive/", "auto-filed", title_col=MINT[2])

# ============ STORY 4 — EFFICIENCY (indigo), 2x2 grid ============
y = cy+CH+92
station("4", y+8, INDIGO)
heading(y, INDIGO, "Efficiency & quality nudges", "Lightweight reminders — they never block, just keep you sharp.")
gy = y+54
gw = (content_w-30)/2
cells = [
  (ic_key, "intellectual-honesty", "verify claims · push back · find the real cause"),
  (ic_key, "tool-acquisition", "never “I can't” — probe, install, then use it"),
  (ic_pen, "secrets-discipline", "name a secret, never echo its value"),
  (ic_commit, "git-mv-unstaged-guard", "git mv of an edited file stages the OLD blob"),
]
for i,(ic,name,sub) in enumerate(cells):
    col = i%2; row=i//2
    x = content_x + col*(gw+30)
    yy = gy + row*(CH+30)
    o(f'<rect x="{x}" y="{yy}" width="{gw}" height="{CH}" rx="16" fill="{INDIGO[0]}" stroke="{INDIGO[1]}" stroke-width="1.5" filter="url(#sh)"/>')
    badge(x+32, yy+CH/2, INDIGO[1], ic)
    o(f'<text x="{x+62}" y="{yy+CH/2-4}" font-size="17.5" font-weight="700" fill="{INDIGO[2]}">{esc(name)}</text>')
    for j,ln in enumerate(wrap(sub, 42)[:1]):
        o(f'<text x="{x+62}" y="{yy+CH/2+18}" font-size="13.5" fill="{MUTE}">{esc(sub)}</text>')

# ---------------- footer ----------------
fy = gy + 2*(CH+30) + 22
o(f'<rect x="{PAD}" y="{fy}" width="{W-2*PAD}" height="78" rx="20" fill="#3A3F57" filter="url(#shx)"/>')
o(f'<text x="{PAD+30}" y="{fy+34}" font-size="15" fill="#AEB6D9">install in Claude Code</text>')
o(f'<text x="{PAD+30}" y="{fy+60}" font-size="18" font-weight="700" fill="#fff" font-family="monospace">/plugin marketplace add dr-snob/claude-planning-harness</text>')
o(f'<circle cx="{W-PAD-44}" cy="{fy+39}" r="22" fill="#12B886"/>')
o(ic_check(W-PAD-44, fy+39))

o('</svg>')
H = int(fy + 78 + 44)          # footer bottom + margin
doc = "\n".join(S).replace("__H__", str(H)).replace("__SY2__", str(int(fy-26)))
open("/tmp/info.svg","w").write(doc)
print("wrote /tmp/info.svg ; height", H)
