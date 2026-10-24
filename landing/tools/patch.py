#!/usr/bin/env python3
"""One-shot content patch for the Breezy landing export."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [ROOT / "index.html", ROOT / "site.webmanifest"]
FILES += sorted((ROOT / "_nuxt").glob("*.js"))
FILES += sorted((ROOT / "_nuxt").glob("*.css"))

REPLACEMENTS = [
    ("hello@emotion-agency.com", "hello@breezy.app"),
    ("https://emotion-agency.com", "https://breezy-info.vercel.app"),
    ("emotion-agency.com", "breezy-info.vercel.app"),
    ("@emotion.agency", "@breezy"),
    ("emotion.agency", "breezy"),
    ("emotion__agency", "breezy"),
    ("emotionagency", "breezy"),
    ("Emotion Agency", "Breezy"),
    ("Emotion AI Assistant", "Breezy Assistant"),
    ("Emotion Serif", "Breezy Serif"),
    ("Emotion Machine Interface", "Breezy interface"),
    ("Emotion Machine", "Breezy"),
    ("EmotionEngine", "BreezyEngine"),
    ("emotion", "breezy"),
    ("Emotion", "Breezy"),
    # Hero 1
    ("Award-winning websites and digital products for the brands of tomorrow",
     "An Android agent for the errands you keep putting off"),
    ('["Where", "ambitious ideas become interfaces people remember"]',
     '["Say it once", "and the tapping stops"]'),
    ('["Where","ambitious ideas become interfaces people remember"]',
     '["Say it once","and the tapping stops"]'),
    ("ambitious ideas become interfaces people remember", "and the tapping stops"),
    (">Where </span>", ">Say it once </span>"),
    # Hero 2
    ('["We&nbsp;", "build", "more than", "websites and products"]',
     '["One", "ask", "then a string of taps", "you never see"]'),
    ('["We&nbsp;","build","more than","websites and products"]',
     '["One","ask","then a string of taps","you never see"]'),
    ("We create digital experiences where technology and creativity speak the same language",
     "Type a goal in plain words. Breezy reads the screen, decides the next tap, and works through the app one step at a time."),
    # Hero 3
    ('["Technology", "as emotion"]', '["The apps", "you already use"]'),
    ('["Technology","as emotion"]', '["The apps","you already use"]'),
    ("We turn code into feeling, motion into meaning, and interaction into memory",
     "You keep your accounts, addresses, and cards. Breezy works inside the apps already on your phone."),
    # Hero 4
    ('["Beauty&nbsp;", "With", "a reason"]', '["Limits", "before", "the tap"]'),
    ('["Beauty&nbsp;","With","a reason"]', '["Limits","before","the tap"]'),
    ("Every pixel has a reason. We design to solve real problems and create value",
     "A per-order cap, a daily cap, an expiry, and a merchant allowlist. When a cart crosses the line, the agent stops and asks you."),
    # Hero 5
    ('["We", "build with people who care how things feel"]',
     '["Made for", "people with better things to do"]'),
    ('["We","build with people who care how things feel"]',
     '["Made for","people with better things to do"]'),
    ("Our best work always comes back to one thing",
     "For the commute, the late grocery run, and the errand you keep moving to tomorrow."),
    # Pills
    (" Approach ", " How it works "),
    (" Vibes ", " Your apps "),
    (" Design ", " Limits "),
    (" OUR PEOPLE ", " WHO IT'S FOR "),
    ("What we do", "What it handles"),
    # What we do body
    ("We design and engineer digital products for ambitious teams — from launch sites to full-scale SaaS platforms. We start with why, then design and build the rest",
     "Breezy handles the small stuff, so your day has fewer tabs."),
    ("More about us ", "See the guardrails "),
    # Services
    ("Marketing Websites", "Cabs and autos"),
    ("Landing Pages &amp; Launches", "Groceries and quick commerce"),
    ("Landing Pages & Launches", "Groceries and quick commerce"),
    ("Brand Identity Systems", "Food and late-night orders"),
    ("Product UX &amp; Design", "Bills and recharges"),
    ("Product UX & Design", "Bills and recharges"),
    ("Web Applications", "Medicine and pharmacy"),
    ("Mobile Applications", "Parcel pickup and drop"),
    ("E-commerce Platforms", "Movie and event tickets"),
    ("SaaS Dashboards", "UPI checkout"),
    ("Custom Motion &amp; Animation", "Recurring orders"),
    ("Custom Motion & Animation", "Recurring orders"),
    ("3D &amp; Interactive Experiences", "Stock and price checks"),
    ("3D & Interactive Experiences", "Stock and price checks"),
    ("Design Systems", "Order tracking"),
    ("AI-Driven Interfaces", "Handoff when stuck"),
    # Projects heading
    ("Some of our projects", "Eight small jobs, handled"),
    (" Some ", " Eight "),
    (" Of our ", " small jobs, "),
    (" projects</span>", " handled</span>"),
    ("> projects", "> handled"),
    ("A selection of projects where design, technology, and strategy come together",
     "Examples, not integrations. Every run stops at the same limits."),
    (" View all projects ", " Read the code "),
    # Awards
    (" Our work has been recognized by leading design platforms and trusted by clients worldwide ",
     "The agent can only spend what the policy allows. Everything else comes back to you."),
    (" Awards ", " Limits "),
    (" recognitions ", " checks "),
    ("Awards &amp; recognitions", "Limits &amp; checks"),
    ("Awards & recognitions", "Limits & checks"),
    ("More about us ", "Read the code "),
    ('"Total: " + b(C(e))', '"Total: " + b(C(e)) + " checks"'),
    # Footer
    ('["Let’s", "build", "something", "meaningful"]',
     '["Put the", "phone", "down.", "Breezy has it."]'),
    ('["Let’s","build","something","meaningful"]',
     '["Put the","phone","down.","Breezy has it."]'),
    ("Let’s build something meaningful", "Put the phone down. Breezy has it."),
    ("Let's build something meaningful", "Put the phone down. Breezy has it."),
    (">Let’s </span>", ">Put the </span>"),
    (">build </span>", ">phone </span>"),
    (">something </span>", ">down. </span>"),
    (">meaningful</span>", ">Breezy has it.</span>"),
    ("Have an idea, a product, or a vision? We’d love to help you bring it to life",
     "Breezy is a working prototype for Android. Read the code, run the demo, or tell us which app to teach it next."),
    ("Start project ", "See the code "),
    ("© 2018-", "© 2026 Breezy. Prototype only. No real money moves. "),
    (". All rights reserved", ""),
    ("Keep scrolling ", "End of the demo "),
    ("Terms of Service", "Prototype"),
    ("Privacy Policy", "No trackers"),
    # Assistant UI
    ("I'm Breezy AI Assistant. Click to interact with me.", "I'm Breezy's site guide. Click to ask about the prototype."),
    ("Hi! I'm your personal AI assistant. I'm here to help you explore this site.",
     "Hi. Ask me about the agent, the limits, or the demo."),
    # Footer location / misc
    ("50000.\nBorn and working in Kryvyi Rih, Ukraine", "Built for Android 11 and up"),
    ("50000. Born and working in Kryvyi Rih, Ukraine", "Built for Android 11 and up"),
    ("Born and working in Kryvyi Rih, Ukraine", "Built for Android 11 and up"),
    ("Kryvyi Rih", "Android"),
    ("Ukraine", ""),
    # Awards data bits that survive
    ("AWWWARDS", "PER-ORDER CAP"),
    ("Awwwards", "GitHub"),
    ("CSS Design Awards", "Daily cap"),
    ("Behance", "Expiry"),
    ("Communication Arts", "Merchant allowlist"),
    ("Codrops", "Owner approval"),
]

TEXT_EXT = {".html", ".js", ".css", ".json", ".webmanifest", ".svg"}


def apply_replacements() -> None:
    for path in FILES:
        if not path.exists() or path.suffix not in TEXT_EXT:
            continue
        text = path.read_text(errors="surrogatepass")
        for old, new in REPLACEMENTS:
            text = text.replace(old, new)
        path.write_text(text, errors="surrogatepass")


def mutate_payload() -> None:
    index = ROOT / "index.html"
    html = index.read_text(errors="surrogatepass")
    match = re.search(r'(<script[^>]*id="__NUXT_DATA__"[^>]*>)(.*?)(</script>)', html, re.S)
    if not match:
        raise SystemExit("payload not found")
    data = json.loads(match.group(2))

    def add(value):
        data.append(value)
        return len(data) - 1

    def ref(value):
        return add(value)

    scenes = [
        ("Cab to the airport", "cab.webp", "Rapido", ["7 taps", "Fare cap"], "Fare under ₹200 and a pickup point that matched.", "Booked and confirmed without opening the app.", "2026-10-01T08:40:00.000Z", "mobility"),
        ("Milk before midnight", "milk.webp", "Blinkit", ["5 taps", "Stock check"], "Two items, one substitution, delivered before the store closed.", "The cart was built from the usual order and paid once.", "2026-09-18T23:12:00.000Z", "grocery"),
        ("Dinner without the scroll", "dinner.webp", "Swiggy", ["6 taps", "Veg filter"], "A late dinner with the veg filter on and a coupon applied.", "The agent found the restaurant and stopped at the cap.", "2026-09-07T20:05:00.000Z", "food"),
        ("The electricity bill", "bill.webp", "BESCOM", ["4 taps", "Amount check"], "A bill that had to clear the daily cap before it could be paid.", "Amount checked, then the owner approved the overage.", "2026-08-22T09:30:00.000Z", "utilities"),
        ("Chemist run", "chemist.webp", "PharmEasy", ["6 taps", "Prescription"], "A prescription upload and a substitution that needed a human.", "The agent stopped at the substitution and asked.", "2026-08-09T19:20:00.000Z", "health"),
        ("Parcel to the courier", "parcel.webp", "Delhivery", ["5 taps", "Slot check"], "A pickup slot that had to fit before the building closed.", "Slot booked, address checked, no extra charge.", "2026-07-27T10:15:00.000Z", "logistics"),
        ("Two seats, same row", "tickets.webp", "BookMyShow", ["8 taps", "Seat check"], "Two seats together under a fixed price ceiling.", "The agent held the row and stopped at checkout.", "2026-07-11T18:00:00.000Z", "tickets"),
        ("Split the auto fare", "fare.webp", "UPI", ["3 taps", "Payee check"], "A fare split with a payee that had to be on the allowlist.", "The agent checked the VPA and the amount.", "2026-06-30T21:05:00.000Z", "payments"),
    ]

    for i, obj_idx in enumerate([6, 35, 54, 71, 93, 110, 128, 148, 167, 184, 198, 213, 228, 247, 260, 276]):
        scene = scenes[i % len(scenes)]
        title, asset, app, steps, challenge, description, iso, industry = scene
        slug = "cab-airport" if i == 0 else (
            "milk-midnight" if i == 1 else (
                "dinner" if i == 2 else (
                    "electricity-bill" if i == 3 else (
                        "chemist" if i == 4 else (
                            "parcel" if i == 5 else (
                                "tickets" if i == 6 else (
                                    "split-fare" if i == 7 else f"scene-{i + 1}")))))))
        obj = data[obj_idx]
        obj["title"] = ref(f"Scene {i + 1}" if i >= 8 else title)
        obj["asset"] = ref(f"/scenes/{asset}" if i < 8 else "/scenes/cab.webp")
        obj["challenge"] = ref(challenge)
        obj["client"] = ref("Demo run")
        obj["created_at"] = add(["Date", iso])
        obj["description"] = ref(description)
        obj["breezy"] = ref("Focus")
        if "emotion" in obj:
            obj["emotion"] = ref("Focus")
        obj["industry"] = add([ref(industry)])
        obj["link"] = ref("https://github.com/Vishi2006/Bridgy")
        obj["nda"] = 8
        obj["scope"] = add([ref(x) for x in steps])
        obj["stack"] = add([
            ref({"role": ref("Check"), "technology": ref(x)}) for x in steps
        ])
        obj["type"] = ref(app)
        obj["slug"] = ref(slug if i < 8 else f"scene-{i + 1}")
        obj["color"] = ref("#9047ff")
        obj["archived"] = 8

    featured_slugs = ["cab-airport", "milk-midnight", "dinner", "electricity-bill", "chemist", "parcel", "tickets", "split-fare"]
    data[291] = [ref(s) for s in featured_slugs]
    match_html = match.group(1) + json.dumps(data, ensure_ascii=False, separators=(",", ":")) + match.group(3)
    html = html[: match.start()] + match_html + html[match.end():]
    index.write_text(html, errors="surrogatepass")


def replace_awards() -> None:
    path = ROOT / "_nuxt" / "BqYnmFZw.js"
    s = path.read_text(errors="surrogatepass")
    new_ac = '''const AC=[{title:"Per-order cap",link:"#limits",modelPath:"/models/duck.glb",modelScale:.3,awards:[{name:"Cart total",count:1,value:"₹200"},{name:"Currency",count:1,value:"INR"},{name:"Merchant",count:1,value:"allowed"},{name:"Hard stop",count:1,value:"on"}]},{title:"Daily cap",link:"#limits",modelPath:"/models/chair.glb",modelScale:.14,awards:[{name:"Spent today",count:1,value:"₹500"},{name:"Resets",count:1,value:"midnight"},{name:"Hard stop",count:1,value:"on"}]},{title:"Expiry",link:"#limits",modelPath:"/models/mountain.glb",modelScale:.12,awards:[{name:"Session key",count:1,value:"24h"},{name:"Re-approve",count:1,value:"needed"},{name:"Revoke",count:1,value:"anytime"}]},{title:"Merchant allowlist",link:"#limits",modelPath:"/models/office.glb",modelScale:.09,awards:[{name:"Settlement vault",count:1,value:"only"},{name:"External address",count:1,value:"blocked"},{name:"Swaps",count:1,value:"blocked"}]},{title:"Owner approval",link:"#limits",modelPath:"/models/duck.glb",modelScale:.16,awards:[{name:"Face or fingerprint",count:1,value:"on"},{name:"Out of policy",count:1,value:"only"}]}],Xce={},'''
    start = s.find("const AC=")
    end = s.find(",Yce=", start)
    if start < 0 or end < 0:
        raise SystemExit("awards block not found")
    # keep the separator after Xce={}, which ends right before Yce
    s = s[:start] + new_ac + s[end + 1:]
    s = s.replace("value:`${r.count}x`", "value:r.value??`${r.count}x`")
    s = s.replace("value: `${r.count}x`", "value: r.value ?? `${r.count}x`")
    path.write_text(s, errors="surrogatepass")


def replace_footer_faq_seo() -> None:
    path = ROOT / "_nuxt" / "BqYnmFZw.js"
    s = path.read_text(errors="surrogatepass")
    start = s.find("Mue=[")
    end = s.find(",Zf=", start)
    if start < 0 or end < 0:
        raise SystemExit("footer block not found")
    new = '''Mue=[{label:"Social",items:[{label:"GitHub",href:"https://github.com/Vishi2006/Bridgy"}]},{label:"Pages",items:[{label:"Home",href:"/",isInternal:!0}]},{label:"Built for",items:[{label:"Android 11 and up"}]},{label:"E-mail",items:[{label:"hello@breezy.app",href:"mailto:hello@breezy.app",isEmail:!0}]}],Iue=[{title:"What is Breezy?",text:"An Android agent that runs small errands inside the apps already on your phone. It reads the screen, taps through the flow, and pays inside the limits you set."},{title:"Does it move real money?",text:"Not yet. Settlement is testnet-only and the UPI checkout shows the policy decision, then stops. Nothing real is charged today."},{title:"Which apps does it work with?",text:"Any app it can see. The demos use Rapido, Blinkit and Swiggy as examples, not partnerships."},{title:"How are the limits enforced?",text:"The agent gets a per-order cap, a daily cap, an expiry and a merchant allowlist. Anything outside that needs owner approval."},{title:"Where is the code?",text:"github.com/Vishi2006/Bridgy. The page is a prototype, not a product you can buy."}],Vp="Breezy",jU="Breezy — Say it once",Rue="An Android agent that runs small errands inside the apps you already use, with spending limits you set. A working prototype.",eD="Say it once, and the tapping stops",jw="An Android agent for the errands you keep putting off",Pue="hello@breezy.app"'''
    s = s[:start] + new + s[end:]
    path.write_text(s, errors="surrogatepass")


def replace_assistant() -> None:
    path = ROOT / "_nuxt" / "BqYnmFZw.js"
    s = path.read_text(errors="surrogatepass")
    start = s.find("Kce=[")
    end = s.find("],Jce=", start)
    if start < 0 or end < 0:
        raise SystemExit("assistant rules not found")
    rules = '''Kce=[{match:/\\b(bye|goodbye|close|exit|stop|end)\\b/i,reply:()=>"Talk soon. [[EXIT]]"},{match:/\\b(hi|hello|hey|yo)\\b/i,reply:()=>"Hey. Ask me about the agent, the limits, or the demo."},{match:/\\b(your names?|whats? your name|who are you|who you are|what are you)\\b/i,reply:()=>"I'm Breezy's site guide."},{match:/\\b(what is breezy|what does breezy do|agent|errand|app)\\b/i,reply:()=>"Breezy is an Android agent. It reads the screen, taps through apps, and pays inside the limits you set."},{match:/\\b(money|pay|payment|charge|settle|wallet)\\b/i,reply:()=>"Settlement is testnet-only today. The checkout shows the policy decision, then stops. No real money moves."},{match:/\\b(apps?|rapido|blinkit|swiggy|zepto|supported)\\b/i,reply:()=>"Any app it can see. The demos use Rapido, Blinkit and Swiggy as examples, not partnerships."},{match:/\\b(safe|limit|policy|guardrail|approval|cap)\\b/i,reply:()=>"The agent gets a per-order cap, a daily cap, an expiry and a merchant allowlist. Anything outside that needs you."},{match:/\\b(code|github|source|repo)\\b/i,reply:()=>"github.com/Vishi2006/Bridgy"},{match:/\\b(contact|email|reach|talk)\\b/i,reply:()=>"hello@breezy.app"},{match:/\\b(socials?|instagram|twitter|linkedin|follow)\\b/i,reply:()=>"GitHub. That's the one."}'''
    s = s[:start] + rules + s[end:]
    s = re.sub(
        r'Jce=\(\)=>"I\'m [^"]*";',
        'Jce=()=>"I\'m Breezy\'s site guide. Ask about the agent, the limits, or the demo.";',
        s,
        count=1,
    )
    s = s.replace(
        'function wU(){return uf!=="unknown"?Promise.resolve():zd||(zd=fetch("/api/tts/speak",{method:"HEAD"}).then(n=>{uf=n.ok?"available":"unavailable"}).catch(()=>{uf="unavailable"}).finally(()=>{zd=null}),zd)}',
        'function wU(){return uf="unavailable",Promise.resolve()}',
    )
    path.write_text(s, errors="surrogatepass")


def replace_seo_and_scripts() -> None:
    index = ROOT / "index.html"
    html = index.read_text(errors="surrogatepass")
    html = re.sub(r"<script[^>]*googletagmanager[^>]*></script>", "", html)
    html = re.sub(r"<script[^>]*>\s*window\.dataLayer.*?</script>", "", html, flags=re.S)
    html = re.sub(
        r'<script type="application/ld\+json">.*?</script>',
        '<script type="application/ld+json">{"@context":"https://schema.org","@type":"SoftwareApplication","name":"Breezy","applicationCategory":"UtilitiesApplication","operatingSystem":"Android","description":"An Android agent that runs small errands inside the apps you already use, with spending limits you own. A working prototype.","url":"https://breezy-info.vercel.app/","offers":{"@type":"Offer","price":"0","priceCurrency":"INR"},"softwareVersion":"prototype"}</script>',
        html,
        flags=re.S,
    )
    html = html.replace(
        '<meta name="description" content="An Android agent for the errands you keep putting off. Design and engineering under one roof since 2018 — 70 international design awards.">',
        '<meta name="description" content="An Android agent that runs small errands inside the apps you already use, with spending limits you set. A working prototype.">',
    )
    html = html.replace(
        'content="An Android agent for the errands you keep putting off. Design and engineering under one roof since 2018 — 70 international design awards."',
        'content="An Android agent that runs small errands inside the apps you already use, with spending limits you set. A working prototype."',
    )
    html = html.replace("Breezy — Interfaces People Remember", "Breezy — Say it once")
    html = html.replace("<title>Breezy — Interfaces People Remember</title>", "<title>Breezy — Say it once</title>")
    html = html.replace("Breezy Agency", "Breezy")
    index.write_text(html, errors="surrogatepass")


def add_logo_css() -> None:
    index = ROOT / "index.html"
    html = index.read_text(errors="surrogatepass")
    css = '''<style id="breezy-brand">.header__logo svg,.mobile-nav__logo svg,.loader__logo svg{display:none!important}.header__logo a::after,.mobile-nav__logo::after,.loader__content::before{content:"breezy";font-family:"Breezy Serif",serif;font-weight:300;line-height:.8;letter-spacing:-.035em;color:var(--foreground);display:block}.header__logo a::after{font-size:2rem}.mobile-nav__logo::after{font-size:2rem}.loader__content::before{font-size:4.5rem;color:var(--primary);text-align:center;margin-bottom:.5rem}</style>'''
    html = html.replace("</head>", css + "</head>")
    index.write_text(html, errors="surrogatepass")


def main() -> None:
    apply_replacements()
    mutate_payload()
    replace_awards()
    replace_footer_faq_seo()
    replace_assistant()
    replace_seo_and_scripts()
    add_logo_css()
    print("patched")


if __name__ == "__main__":
    main()
