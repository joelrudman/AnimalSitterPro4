AMBER = "#D98819"

# ---------- illustrated placeholder portraits ----------
PEOPLE = {
 "sam":   dict(bg="#F3D9B1", skin="#8D5524", hair="#1B1B1B", shirt="#2F4858", style="short", beard=True),
 "jo":    dict(bg="#CFE3F0", skin="#F1C7A5", hair="#B5562A", shirt="#3A3A3A", style="long", beard=False),
 "priya": dict(bg="#E4D7F2", skin="#C68B59", hair="#22160F", shirt="#7A2E4D", style="bun", beard=False),
 "marcus":dict(bg="#D6EBD3", skin="#E8B68F", hair="#6B4A2B", shirt="#3C6E47", style="short", beard=False),
 "ellie": dict(bg="#F6D3D3", skin="#F5D0B5", hair="#E3B65B", shirt="#28536B", style="long", beard=False),
 "tom":   dict(bg="#E9E3C9", skin="#D9A077", hair="#8C8C8C", shirt="#5A3E2B", style="short", beard=True),
}

def portrait(key, cls="", attrs=""):
    p = PEOPLE[key]
    hair_back = hair_front = extra = ""
    if p["style"] == "long":
        hair_back = f'<path d="M27 48 Q26 18 50 17 Q74 18 73 48 L76 86 Q50 92 24 86 Z" fill="{p["hair"]}"/>'
        hair_front = f'<path d="M30 42 Q31 19 50 19 Q70 19 70 42 Q62 30 50 31 Q38 30 30 42 Z" fill="{p["hair"]}"/>'
    elif p["style"] == "bun":
        extra = f'<circle cx="50" cy="14" r="9" fill="{p["hair"]}"/>'
        hair_front = f'<path d="M30 44 Q30 19 50 19 Q70 19 70 44 Q66 30 50 29 Q34 30 30 44 Z" fill="{p["hair"]}"/>'
    else:
        hair_front = f'<path d="M30 42 Q29 18 50 18 Q71 18 70 42 Q68 29 50 28 Q32 29 30 42 Z" fill="{p["hair"]}"/>'
    beard = f'<path d="M33 50 Q34 70 50 71 Q66 70 67 50 Q64 62 50 63 Q36 62 33 50 Z" fill="{p["hair"]}" opacity=".9"/>' if p["beard"] else ""
    return f'''<svg class="{cls}" {attrs} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg">
<rect width="100" height="100" fill="{p["bg"]}"/>{hair_back}{extra}
<path d="M14 104 Q16 74 50 72 Q84 74 86 104 Z" fill="{p["shirt"]}"/>
<rect x="43" y="58" width="14" height="16" rx="5" fill="{p["skin"]}"/>
<ellipse cx="50" cy="45" rx="19" ry="22" fill="{p["skin"]}"/>{beard}{hair_front}
<circle cx="43" cy="46" r="2.1" fill="#2A1E17"/><circle cx="57" cy="46" r="2.1" fill="#2A1E17"/>
<path d="M44 56 Q50 60 56 56" stroke="#2A1E17" stroke-width="1.8" fill="none" stroke-linecap="round"/>
</svg>'''

# ---------- icons (SF Symbol look-alikes) ----------
def mug(size=22, color=AMBER):
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24"><path d="M4 6.5h11v11a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3z" fill="{color}"/><path d="M15 9h2.2a2.8 2.8 0 0 1 0 5.6H15" stroke="{color}" stroke-width="2" fill="none"/><path d="M4.5 6.5c0-2 1.6-3.3 3.3-3 .8-1 2.6-1.3 3.7-.4 1.5-.3 3 .9 3 2.6v.8z" fill="{color}" opacity=".55"/></svg>'
def star(size=14, color="#F5C400"):
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24"><path d="M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3l-5.9 3.3 1.3-6.6-4.9-4.6 6.6-.8z" fill="{color}"/></svg>'
def star_outline(size=22, color=AMBER):
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24"><path d="M12 3.2l2.7 5.6 6.1.8-4.5 4.2 1.2 6.1L12 16.9l-5.5 3 1.2-6.1-4.5-4.2 6.1-.8z" fill="none" stroke="{color}" stroke-width="1.8" stroke-linejoin="round"/></svg>'
def chevron(color="#C4C4C7"):
    return f'<svg width="8" height="13" viewBox="0 0 8 13"><path d="M1.5 1.5l5 5-5 5" stroke="{color}" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'
def plus(color=AMBER):
    return f'<svg width="20" height="20" viewBox="0 0 20 20"><path d="M10 3v14M3 10h14" stroke="{color}" stroke-width="2.4" stroke-linecap="round"/></svg>'
def ellipsis(color=AMBER):
    return f'<svg width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="none" stroke="{color}" stroke-width="1.7"/><circle cx="7.5" cy="12" r="1.4" fill="{color}"/><circle cx="12" cy="12" r="1.4" fill="{color}"/><circle cx="16.5" cy="12" r="1.4" fill="{color}"/></svg>'
def camera_icon(color=AMBER):
    return f'<svg width="17" height="17" viewBox="0 0 24 24"><path d="M3 8h4l2-3h6l2 3h4v11H3z" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round"/><circle cx="12" cy="13" r="3.6" fill="none" stroke="{color}" stroke-width="2"/></svg>'
def photo_icon(color=AMBER):
    return f'<svg width="17" height="17" viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2.5" fill="none" stroke="{color}" stroke-width="2"/><path d="M5 17l4.5-5 3.5 3.5 2.5-2.5L19 17" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round"/><circle cx="16" cy="9" r="1.5" fill="{color}"/></svg>'
def trash_icon(color="#FF3B30"):
    return f'<svg width="16" height="16" viewBox="0 0 24 24"><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round"/></svg>'
def check_circle(color="#34C759"):
    return f'<svg width="20" height="20" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="{color}"/><path d="M7 12.5l3.2 3.2L17 9" stroke="#fff" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'
def search_icon(color="#8E8E93"):
    return f'<svg width="16" height="16" viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="{color}" stroke-width="2.4"/><path d="M15.5 15.5L21 21" stroke="{color}" stroke-width="2.4" stroke-linecap="round"/></svg>'
def back_chevron(color=AMBER):
    return f'<svg width="12" height="20" viewBox="0 0 12 20"><path d="M10 2L2 10l8 8" stroke="{color}" stroke-width="2.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'

def tab_icon(kind, color):
    if kind == "here":
        return f'<svg width="28" height="26" viewBox="0 0 28 26"><path d="M14 2a7 7 0 0 1 7 7c0 5-7 11-7 11S7 14 7 9a7 7 0 0 1 7-7z" fill="{color}"/><circle cx="14" cy="9" r="2.6" fill="#fff"/><ellipse cx="14" cy="22.5" rx="9" ry="2.2" fill="none" stroke="{color}" stroke-width="1.6"/></svg>'
    if kind == "directory":
        return f'<svg width="30" height="26" viewBox="0 0 30 26"><circle cx="11" cy="8" r="4.6" fill="{color}"/><path d="M2 22c0-5 4-8 9-8s9 3 9 8z" fill="{color}"/><circle cx="21" cy="9" r="3.8" fill="{color}" opacity=".75"/><path d="M19 15c5 0 9 2.5 9 7h-6.5" fill="{color}" opacity=".75"/></svg>'
    return f'<svg width="26" height="26" viewBox="0 0 24 24"><path d="M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7zm8.4 4.6l1.9 1.5-2 3.4-2.3-.9a8 8 0 0 1-1.9 1.1L15.8 21h-3.9l-.4-2.4a8 8 0 0 1-1.9-1.1l-2.3.9-2-3.4 1.9-1.5a8 8 0 0 1 0-2.2L5.3 9.8l2-3.4 2.3.9a8 8 0 0 1 1.9-1.1L11.9 3.8h3.9l.4 2.4a8 8 0 0 1 1.9 1.1l2.3-.9 2 3.4-1.9 1.5a8 8 0 0 1 0 2.2z" fill="none" stroke="{color}" stroke-width="1.7"/></svg>'

def status_bar(dark=False, time="9:41"):
    c = "#fff" if dark else "#000"
    return f'''<div class="status" style="color:{c}"><span class="time">{time}</span>
<span class="sicons"><svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1" fill="{c}"/><rect x="5" y="5.5" width="3" height="6.5" rx="1" fill="{c}"/><rect x="10" y="3" width="3" height="9" rx="1" fill="{c}"/><rect x="15" y="0" width="3" height="12" rx="1" fill="{c}"/></svg>
<svg width="16" height="12" viewBox="0 0 16 12"><path d="M8 11.5l2.4-2.6a3.4 3.4 0 0 0-4.8 0z M3.6 6.9a6.2 6.2 0 0 1 8.8 0l1.5-1.6a8.4 8.4 0 0 0-11.8 0z M.7 3.8a10.4 10.4 0 0 1 14.6 0L16 3A11.5 11.5 0 0 0 0 3z" fill="{c}"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.5" fill="none" stroke="{c}" opacity=".4"/><rect x="2" y="2" width="17" height="9" rx="2" fill="{c}"/><path d="M25 4.5v4a2 2 0 0 0 0-4z" fill="{c}" opacity=".4"/></svg></span></div>
<div class="island"></div>'''

def tab_bar(active):
    items = [("here","Here"),("directory","Directory"),("settings","Settings")]
    out = '<div class="tabbar">'
    for k, label in items:
        col = AMBER if k == active else "#999"
        out += f'<div class="tab" style="color:{col}">{tab_icon(k,col)}<span>{label}</span></div>'
    return out + '<div class="homebar"></div></div>'

def banner_ad():
    return f'''<div class="adbar"><div class="ad">
<div class="adlogo">🎟️</div>
<div class="adtext"><div class="adtitle">Bristol Beer Festival 2026</div><div class="adsub">Tickets on sale now · bristolbeerfest.example</div></div>
<div class="adbtn">Book</div><div class="adbadge">Ad</div></div></div>'''

def row(key, name, note, fav=False, chevron_on=True):
    s = star() if fav else ""
    return f'''<div class="row"><div class="av48">{portrait(key)}</div>
<div class="rowtext"><div class="rname">{name} {s}</div><div class="rnote">{note}</div></div>{chevron() if chevron_on else ""}</div>'''

def fake_map(h=160):
    return f'''<svg width="100%" height="{h}" viewBox="0 0 345 {h}" preserveAspectRatio="xMidYMid slice">
<rect width="345" height="{h}" fill="#EDE9E1"/>
<path d="M-10 118 Q80 100 170 128 T360 112" stroke="#A9CBE8" stroke-width="18" fill="none"/>
<rect x="228" y="12" width="90" height="52" rx="8" fill="#CFE5C4"/>
<path d="M0 60 H345 M0 30 L345 52 M120 0 V{h} M60 0 L95 {h} M250 0 L210 {h} M300 0 V{h}" stroke="#fff" stroke-width="7"/>
<path d="M0 60 H345 M120 0 V{h}" stroke="#F8E3A3" stroke-width="5"/>
<text x="128" y="54" font-size="9" fill="#8a8578" font-family="Inter">High St</text>
<text x="246" y="42" font-size="9" fill="#6f8f62" font-family="Inter">Castle Park</text>
<g transform="translate(160,54)"><circle r="17" fill="{AMBER}" stroke="#fff" stroke-width="3"/><g transform="translate(-10,-10)">{mug(20,"#fff")}</g><path d="M-6 15 L0 24 L6 15" fill="{AMBER}"/></g>
</svg>'''

CSS = f'''
*{{box-sizing:border-box;margin:0;padding:0}}
body{{font-family:Inter,-apple-system,sans-serif;background:#1c1c1e;-webkit-font-smoothing:antialiased;font-feature-settings:"cv11","ss01"}}
.device{{width:417px;height:876px;border-radius:68px;background:#0b0b0c;padding:12px;box-shadow:0 0 0 2px #3a3a3c inset, 0 30px 60px rgba(0,0,0,.35)}}
.phone{{width:393px;height:852px;border-radius:56px;overflow:hidden;position:relative;background:#F2F2F7;color:#000}}
.status{{position:absolute;top:0;left:0;right:0;height:54px;display:flex;justify-content:space-between;align-items:center;padding:4px 30px 0 48px;z-index:5;font-weight:600;font-size:17px}}
.sicons{{display:flex;gap:6px;align-items:center}}
.island{{position:absolute;top:11px;left:50%;transform:translateX(-50%);width:125px;height:37px;border-radius:20px;background:#000;z-index:6}}
.content{{position:absolute;top:54px;left:0;right:0;bottom:0;overflow:hidden}}
.toolbar{{height:44px;display:flex;align-items:center;justify-content:flex-end;padding:0 18px;gap:18px;color:{AMBER};font-size:17px}}
.toolbar.split{{justify-content:space-between}}
.ltitle{{font-size:34px;font-weight:700;letter-spacing:-.6px;padding:2px 20px 8px}}
.card{{background:#fff;border-radius:12px;margin:0 16px;overflow:hidden}}
.shead{{font-size:13px;color:#6D6D72;text-transform:uppercase;padding:18px 36px 7px;letter-spacing:.1px}}
.sfoot{{font-size:13px;color:#6D6D72;padding:7px 36px 0;line-height:1.38}}
.row{{display:flex;align-items:center;gap:12px;padding:9px 16px;position:relative}}
.row+.row::before,.cell+.cell::before{{content:"";position:absolute;top:0;right:0;left:76px;border-top:.5px solid #C6C6C8}}
.cell+.cell::before{{left:16px}}
.av48{{width:48px;height:48px;border-radius:50%;overflow:hidden;flex:none}}
.av48 svg{{width:100%;height:100%;display:block}}
.rowtext{{flex:1;min-width:0}}
.rname{{font-weight:600;font-size:17px;display:flex;align-items:center;gap:5px}}
.rnote{{color:#8A8A8E;font-size:15px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-top:1px}}
.cell{{padding:12px 16px;font-size:17px;display:flex;align-items:center;justify-content:space-between;position:relative;min-height:44px}}
.muted{{color:#8A8A8E}}
.tint{{color:{AMBER}}}
.tabbar{{position:absolute;bottom:0;left:0;right:0;height:83px;background:rgba(249,249,249,.94);border-top:.5px solid #B2B2B2;display:flex;justify-content:space-around;padding-top:7px;z-index:4}}
.tab{{display:flex;flex-direction:column;align-items:center;gap:2px;font-size:10px;font-weight:500;width:90px}}
.homebar{{position:absolute;bottom:8px;left:50%;transform:translateX(-50%);width:134px;height:5px;border-radius:3px;background:#000}}
.adbar{{position:absolute;bottom:83px;left:0;right:0;height:62px;background:rgba(249,249,249,.94);border-top:.5px solid #D0D0D0;z-index:4;display:flex;align-items:center;justify-content:center}}
.ad{{width:393px;height:62px;display:flex;align-items:center;gap:10px;padding:0 12px;position:relative;background:linear-gradient(90deg,#fff,#FFF7EA)}}
.adlogo{{width:40px;height:40px;border-radius:9px;background:#2F4858;display:flex;align-items:center;justify-content:center;font-size:20px}}
.adtext{{flex:1}}.adtitle{{font-size:14px;font-weight:600}}.adsub{{font-size:11.5px;color:#777;margin-top:1px}}
.adbtn{{background:#1A73E8;color:#fff;font-size:13px;font-weight:600;padding:7px 14px;border-radius:16px}}
.adbadge{{position:absolute;top:3px;left:3px;font-size:8.5px;font-weight:700;background:#F5B800;color:#fff;padding:0 4px;border-radius:3px;line-height:12px}}
.pill{{display:inline-flex;align-items:center;gap:6px;background:rgba(217,136,25,.13);color:{AMBER};font-weight:600;font-size:15px;padding:7px 13px;border-radius:18px}}
.pill.red{{background:rgba(255,59,48,.12);color:#FF3B30}}
.toggle{{width:51px;height:31px;border-radius:16px;background:#34C759;position:relative;flex:none}}
.toggle::after{{content:"";position:absolute;right:2px;top:2px;width:27px;height:27px;border-radius:50%;background:#fff;box-shadow:0 2px 4px rgba(0,0,0,.2)}}
'''

def page(inner):
    return inner

# ---------- screens ----------
def here():
    return f'''<div class="phone">{status_bar()}<div class="content">
<div class="toolbar">{plus()}</div><div class="ltitle">Here</div>
<div class="card" style="margin-top:6px"><div style="display:flex;gap:12px;padding:14px 16px">
<div style="width:36px;padding-top:6px">{mug(28)}</div><div>
<div style="font-size:12px;color:#8A8A8E">Looks like you're at</div>
<div style="font-size:21px;font-weight:700;letter-spacing:-.3px;margin-top:1px">The Crown &amp; Anchor</div>
<div style="font-size:15px;color:#8A8A8E;margin-top:2px">14 High Street, Bristol</div>
<div class="tint" style="font-size:15px;margin-top:9px">Not here? Change pub</div></div></div></div>
<div class="shead">Bartenders here (3)</div>
<div class="card">
{row("sam","Sam Okafor","Pulls the best Guinness in town. Ask about…",True)}
{row("jo","Jo Fletcher","Cocktail wizard — try her espresso martini")}
{row("priya","Priya Shah","Hosts quiz night on Thursdays. Remembers…")}
</div></div>{banner_ad()}{tab_bar("here")}</div>'''

def add():
    return f'''<div class="phone" style="background:#000">{status_bar(dark=True)}
<div style="position:absolute;top:58px;left:10px;right:10px;height:30px;border-radius:12px 12px 0 0;background:#8b8b90;opacity:.55"></div>
<div style="position:absolute;top:66px;left:0;right:0;bottom:0;background:#F2F2F7;border-radius:12px 12px 0 0;overflow:hidden">
<div style="height:56px;display:flex;align-items:center;justify-content:space-between;padding:0 18px;font-size:17px">
<span class="tint">Cancel</span><span style="font-weight:600">New bartender</span><span class="tint" style="font-weight:600">Save</span></div>
<div style="display:flex;flex-direction:column;align-items:center;gap:12px;padding:8px 0 4px">
<div style="width:140px;height:140px;border-radius:50%;overflow:hidden">{portrait("priya", attrs='width="140" height="140"')}</div>
<div style="display:flex;gap:10px"><span class="pill">{camera_icon()} Camera</span><span class="pill">{photo_icon()} Library</span><span class="pill red">{trash_icon()} Remove</span></div>
<div style="font-size:12px;color:#8A8A8E">Ask before you take someone's photo.</div></div>
<div class="shead">Name</div><div class="card"><div class="cell">Priya Shah<span style="width:2px;height:22px;background:{AMBER};margin-left:2px;margin-right:auto"></span></div></div>
<div class="shead">Description</div><div class="card"><div class="cell" style="align-items:flex-start;min-height:104px;line-height:1.35">Hosts quiz night on Thursdays. Remembers everyone's order. Recommends the Butcombe Original.</div></div>
<div class="shead">Pub</div><div class="card"><div class="cell" style="justify-content:flex-start;gap:12px">{mug(20)}<div style="flex:1"><div>The Crown &amp; Anchor</div><div style="font-size:12px;color:#8A8A8E">14 High Street, Bristol</div></div>{chevron()}</div></div>
<div class="homebar" style="bottom:8px"></div></div></div>'''

def detail():
    return f'''<div class="phone" style="background:#fff">{status_bar()}<div class="content">
<div class="toolbar split"><span style="display:flex;align-items:center;gap:6px">{back_chevron()} Here</span><span style="display:flex;gap:18px;align-items:center">{star(22, AMBER)}{ellipsis()}</span></div>
<div style="padding:8px 16px 0">
<div style="height:250px;border-radius:20px;overflow:hidden">{portrait("sam", attrs='width="361" height="250"')}</div>
<div style="text-align:center;margin-top:16px"><div style="font-size:32px;font-weight:700;letter-spacing:-.5px;display:flex;justify-content:center;align-items:center;gap:8px">Sam Okafor {star(22)}</div>
<div style="display:flex;justify-content:center;align-items:center;gap:6px;color:#8A8A8E;font-size:16px;margin-top:4px">{mug(17,"#8A8A8E")} The Crown &amp; Anchor</div></div>
<div style="background:#F2F2F7;border-radius:12px;padding:14px 16px;margin-top:16px"><div style="font-weight:600;font-size:17px">Description</div>
<div style="font-size:16px;margin-top:5px;line-height:1.38">Pulls the best Guinness in town. Ask about the guest ales — he'll let you try before you buy. Big Bristol City fan.</div></div>
<div style="background:#F2F2F7;border-radius:12px;overflow:hidden;margin-top:16px">{fake_map(104)}
<div style="display:flex;align-items:center;padding:12px 16px"><div style="flex:1"><div style="font-weight:600">The Crown &amp; Anchor</div><div style="font-size:12px;color:#8A8A8E">14 High Street, Bristol</div></div><span class="pill" style="font-size:14px">Directions</span></div></div>
</div></div>{tab_bar("here")}</div>'''

def pubhead(name, dist):
    return f'<div class="shead" style="display:flex;justify-content:space-between;align-items:center;padding-left:32px;padding-right:32px"><span style="display:flex;align-items:center;gap:6px">{mug(15,"#6D6D72")} {name}</span><span style="text-transform:none;font-size:12px">{dist}</span></div>'

def directory():
    return f'''<div class="phone">{status_bar()}<div class="content">
<div class="toolbar">{star_outline()}</div><div class="ltitle">Directory</div>
<div style="margin:0 16px 2px;background:#E3E3E8;border-radius:10px;height:36px;display:flex;align-items:center;gap:7px;padding:0 9px;color:#8E8E93;font-size:17px">{search_icon()} Bartenders, pubs, notes</div>
{pubhead("The Crown &amp; Anchor","20 m")}
<div class="card">{row("sam","Sam Okafor","Pulls the best Guinness in town…",True)}{row("jo","Jo Fletcher","Cocktail wizard — try her espresso…")}{row("priya","Priya Shah","Hosts quiz night on Thursdays…")}</div>
{pubhead("The Old Duke","350 m")}
<div class="card">{row("marcus","Marcus Bell","Jazz nights Sunday. Knows every…")}{row("ellie","Ellie Hart","Ex-barista, great with recommendations",True)}</div>
{pubhead("The Rose of Denmark","2.1 km")}
<div class="card">{row("tom","Tom Reilly","Landlord. Irish, loves a chat about…")}</div>
</div>{banner_ad()}{tab_bar("directory")}</div>'''

def settings():
    return f'''<div class="phone">{status_bar()}<div class="content">
<div class="toolbar"></div><div class="ltitle">Settings</div>
<div class="shead" style="padding-top:8px">Arrival alerts</div>
<div class="card"><div class="cell">Show bartenders I know when I arrive<div class="toggle"></div></div>
<div class="cell" style="justify-content:flex-start;gap:10px;color:#34C759">{check_circle()} Works even when the app is closed</div></div>
<div class="sfoot">Walk into a pub where you've saved bartenders and a Live Activity shows their names on your Lock Screen and in the Dynamic Island.</div>
<div class="shead">iCloud backup</div>
<div class="card"><div class="cell">Status<span class="muted">Backing up to iCloud</span></div><div class="cell">Last synced<span class="muted">2 minutes ago</span></div><div class="cell">Bartenders saved<span class="muted">6</span></div></div>
<div class="sfoot">Stored in your private iCloud. On a new iPhone, sign in with the same Apple ID and everything comes back by itself.</div>
<div class="shead">Adverts</div>
<div class="card"><div class="cell"><span class="tint" style="display:flex;align-items:center;gap:10px"><svg width="20" height="20" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="{AMBER}" stroke-width="2"/><path d="M5.6 5.6l12.8 12.8" stroke="{AMBER}" stroke-width="2"/></svg>Remove ads</span><span class="muted">£2.99</span></div>
<div class="cell tint">Restore purchases</div><div class="cell tint">Ad privacy choices</div></div>
</div>{tab_bar("settings")}</div>'''

def la_people(size, names, light_text=True, extra=0):
    out = '<div style="display:flex;gap:14px;align-items:flex-start">'
    for key, n in names:
        out += f'<div style="width:{size+14}px;display:flex;flex-direction:column;align-items:center;gap:4px"><div style="width:{size}px;height:{size}px;border-radius:50%;overflow:hidden;box-shadow:0 0 0 1px rgba(255,255,255,.25)">{portrait(key, attrs=f"width={size} height={size}")}</div><span style="font-size:12px;font-weight:500;color:#fff">{n}</span></div>'
    if extra:
        out += f'<div style="width:{size}px;height:{size}px;border-radius:50%;background:rgba(255,255,255,.15);color:rgba(255,255,255,.85);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:15px">+{extra}</div>'
    return out + '</div>'

def live_activity_card():
    return f'''<div style="background:rgba(20,20,22,.72);backdrop-filter:blur(20px);border-radius:24px;padding:16px;color:#fff">
<div style="display:flex;align-items:center;gap:10px"><div style="width:36px;height:36px;border-radius:50%;background:{AMBER};display:flex;align-items:center;justify-content:center">{mug(20,"#fff")}</div>
<div style="flex:1"><div style="font-weight:600;font-size:17px">You're at The Crown &amp; Anchor</div><div style="font-size:15px;color:rgba(255,255,255,.7)">3 bartenders you know</div></div>
<div style="font-size:12px;color:rgba(255,255,255,.6);align-self:flex-start;padding-top:3px">21:14</div></div>
<div style="margin-top:12px">{la_people(46,[("sam","Sam"),("jo","Jo"),("priya","Priya")])}</div></div>'''

WALL = "background:radial-gradient(120% 70% at 30% 20%,#6b3a1f 0%,#2b1a2f 45%,#0d1b2a 100%)"

def lock_controls():
    btn = lambda icon: f'<div style="width:50px;height:50px;border-radius:50%;background:rgba(255,255,255,.18);backdrop-filter:blur(10px);display:flex;align-items:center;justify-content:center">{icon}</div>'
    torch = '<svg width="20" height="22" viewBox="0 0 20 24"><path d="M5 2h10v4l-3 5v11H8V11L5 6z" fill="#fff"/></svg>'
    cam = camera_icon("#fff").replace('width="17" height="17"','width="22" height="22"')
    return f'<div style="position:absolute;bottom:40px;left:46px;right:46px;display:flex;justify-content:space-between">{btn(torch)}{btn(cam)}</div><div class="homebar" style="background:#fff"></div>'

def lockscreen():
    return f'''<div class="phone" style="{WALL};color:#fff">{status_bar(dark=True, time="")}
<div style="position:absolute;top:58px;width:100%;text-align:center"><svg width="14" height="16" viewBox="0 0 14 16"><rect x="1" y="7" width="12" height="9" rx="2" fill="#fff"/><path d="M3.5 7V5a3.5 3.5 0 0 1 7 0v2" stroke="#fff" stroke-width="2" fill="none"/></svg>
<div style="font-size:21px;font-weight:600;margin-top:10px;opacity:.85">Wednesday 4 November</div>
<div style="font-size:96px;font-weight:700;letter-spacing:-3px;line-height:1;margin-top:2px;font-family:'Inter Display',Inter">21:14</div></div>
<div style="position:absolute;left:12px;right:12px;bottom:128px">{live_activity_card()}</div>{lock_controls()}</div>'''

def lock_notification():
    return f'''<div class="phone" style="{WALL};color:#fff">{status_bar(dark=True, time="")}
<div style="position:absolute;top:58px;width:100%;text-align:center"><svg width="14" height="16" viewBox="0 0 14 16"><rect x="1" y="7" width="12" height="9" rx="2" fill="#fff"/><path d="M3.5 7V5a3.5 3.5 0 0 1 7 0v2" stroke="#fff" stroke-width="2" fill="none"/></svg>
<div style="font-size:21px;font-weight:600;margin-top:10px;opacity:.85">Wednesday 4 November</div>
<div style="font-size:96px;font-weight:700;letter-spacing:-3px;line-height:1;margin-top:2px;font-family:'Inter Display',Inter">21:14</div></div>
<div style="position:absolute;left:10px;right:10px;bottom:128px;background:rgba(245,245,245,.78);backdrop-filter:blur(20px);border-radius:22px;padding:13px 14px;color:#000;display:flex;gap:11px">
<div style="width:38px;height:38px;border-radius:9px;background:{AMBER};display:flex;align-items:center;justify-content:center;flex:none">{mug(24,"#fff")}</div>
<div style="flex:1"><div style="display:flex;justify-content:space-between;font-size:13px;color:#555"><span style="font-weight:600;text-transform:uppercase;letter-spacing:.2px">Time Sensitive</span><span>now</span></div>
<div style="font-weight:600;font-size:15px;margin-top:2px">You're at The Crown &amp; Anchor</div>
<div style="font-size:15px;line-height:1.3">Bartenders you know here: Sam, Jo and Priya</div></div></div>
{lock_controls()}</div>'''

def home_icons():
    cols = ["#34C759","#0A84FF","#FF9500","#FF2D55","#5E5CE6","#64D2FF","#FFD60A","#BF5AF2","#30B0C7","#FF453A","#A2845E","#32D74B","#0A84FF","#FF9F0A","#8E8E93","#66D4CF"]
    out = '<div style="position:absolute;top:250px;left:27px;right:27px;display:grid;grid-template-columns:repeat(4,62px);justify-content:space-between;row-gap:30px">'
    for c in cols:
        out += f'<div style="width:62px;height:62px;border-radius:15px;background:{c};opacity:.9"></div>'
    return out + '</div>'

def island():
    return f'''<div class="phone" style="background:linear-gradient(160deg,#c9d6ff 0%,#e2e2e2 60%,#f5e1c8 100%)">{status_bar()}{home_icons()}
<div style="position:absolute;inset:0;backdrop-filter:blur(2px);background:rgba(255,255,255,.12)"></div>
<div style="position:absolute;top:11px;left:11px;right:11px;background:#000;border-radius:46px;padding:22px 22px 20px;color:#fff;z-index:7">
<div style="display:flex;justify-content:space-between;align-items:center"><span style="display:flex;align-items:center;gap:8px;font-weight:600;font-size:17px">{mug(22)} The Crown &amp; Anchor</span><span style="color:rgba(255,255,255,.6);font-size:15px">3 here</span></div>
<div style="margin-top:14px">{la_people(42,[("sam","Sam"),("jo","Jo"),("priya","Priya")])}</div></div>
<div style="position:absolute;bottom:150px;left:0;right:0;text-align:center;z-index:7">
<div style="font-size:13px;font-weight:600;color:#3a3a3c;margin-bottom:10px;letter-spacing:.2px">COMPACT (when not expanded)</div>
<div style="display:inline-flex;align-items:center;justify-content:space-between;width:250px;height:37px;border-radius:20px;background:#000;padding:0 14px;color:#fff;font-size:13px;font-weight:600">{mug(18)}<span>Sam +2</span></div></div>
<div class="homebar"></div></div>'''

SCREENS = [
  ("01-here", "Here: the pub you're in", here),
  ("02-add-bartender", "Add a bartender", add),
  ("03-bartender-detail", "Bartender detail", detail),
  ("04-directory", "Directory, grouped by pub", directory),
  ("05-live-activity-lock-screen", "Live Activity on arrival", lockscreen),
  ("06-dynamic-island", "Dynamic Island", island),
  ("07-arrival-notification", "If the app is closed", lock_notification),
  ("08-settings", "Settings", settings),
]

def write():
    # individual pages
    for slug, title, fn in SCREENS:
        open(f"{slug}.html","w").write(f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS} body{{background:transparent;padding:0}}</style></head><body><div class="device" id="shot">{fn()}</div></body></html>')
    # overview
    cards = "".join(f'<figure><div class="device">{fn()}</div><figcaption>{title}</figcaption></figure>' for slug,title,fn in SCREENS)
    open("overview.html","w").write(f'''<!doctype html><html><head><meta charset="utf-8"><style>{CSS}
body{{background:#F4EFE8;padding:56px 60px 64px}}
h1{{font-size:44px;letter-spacing:-1px;color:#1d1d1f}} .sub{{color:#6e6e73;font-size:19px;margin:8px 0 40px}}
.grid{{display:grid;grid-template-columns:repeat(4,417px);gap:44px 48px}}
figure{{display:flex;flex-direction:column;align-items:center;gap:16px}} figcaption{{font-size:20px;font-weight:600;color:#1d1d1f}}
</style></head><body id="shot"><h1>Pourtrait</h1><div class="sub">Remember who's behind the bar. Design mockups of the iPhone app. Portraits are placeholder illustrations, and the advert is a sample of the single banner.</div><div class="grid">{cards}</div></body></html>''')

write()
print("ok")
