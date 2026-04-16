import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BOOK6_MODULE = ROOT / "modules" / "rulesets" / "magnakai" / "book6.psm1"
BOOK6_COMBAT = ROOT / "modules" / "rulesets" / "magnakai" / "combat.psm1"
CORE_RULESET = ROOT / "modules" / "core" / "ruleset.psm1"
LOG_MD = ROOT / "testing" / "logs" / "BOOK6_AUTOMATION_AUDIT_20260415.md"
LOG_JSON = ROOT / "testing" / "logs" / "BOOK6_AUTOMATION_AUDIT_20260415.json"


def get_function_slice(text: str, name: str, next_name: str | None = None) -> str:
    start = text.index(f"function {name}")
    if next_name is None:
        end = len(text)
    else:
        end = text.index(f"function {next_name}", start)
    return text[start:end]


def extract_switch_sections(text: str) -> set[int]:
    return {int(match.group(1)) for match in re.finditer(r"^\s*(\d+)\s*\{", text, re.MULTILINE)}


def extract_current_section_conditions(text: str) -> set[int]:
    return {int(match.group(1)) for match in re.finditer(r"CurrentSection -eq (\d+)", text)}


book6_text = BOOK6_MODULE.read_text(encoding="utf-8")
combat_text = BOOK6_COMBAT.read_text(encoding="utf-8")
ruleset_text = CORE_RULESET.read_text(encoding="utf-8")

instant_death_slice = get_function_slice(
    book6_text,
    "Get-LWMagnakaiBookSixInstantDeathCause",
    "Invoke-LWMagnakaiBookSixSectionEntryRules",
)
entry_slice = get_function_slice(
    book6_text,
    "Invoke-LWMagnakaiBookSixSectionEntryRules",
    "Apply-LWMagnakaiBookSixStartingEquipment",
)
random_slice = get_function_slice(
    book6_text,
    "Get-LWMagnakaiBookSixSectionRandomNumberContext",
    "Invoke-LWMagnakaiBookSixStorySectionAchievementTriggers",
)

instant_death_sections = extract_switch_sections(instant_death_slice)
entry_sections = extract_switch_sections(entry_slice)
random_sections = extract_switch_sections(random_slice)
combat_sections = extract_current_section_conditions(combat_text)

if "Invoke-LWMagnakaiBookSixSection284BettingRound" in ruleset_text:
    random_sections.add(284)


CANDIDATES = {
    "instant_death": [
        (29, "Arrows at Tekaro gate kill you outright"),
        (36, "Horse fails wagon jump; death under the horse"),
        (52, "Archers kill you on the highway to Varetta"),
        (57, "Crossbow bolt at Denka Gate kills you"),
        (80, "Dakomyd pit and acid death"),
        (84, "Drugged wine; taxidermist ending"),
        (90, "Dakomyd pit without light source"),
        (99, "Pike ambush ends the run"),
        (128, "Two Yawshaths in their lair kill you"),
        (161, "Robbers take your pouch, then murder you"),
        (192, "Two Yawshaths in the dungeon kill you"),
        (218, "Trampled on the bridge"),
        (242, "Temple congregation hacks you to pieces"),
        (257, "Energy bolt throws you onto the altar"),
        (311, "Yawshath body carries you over the edge"),
        (323, "Dakomyd blood destroys your weapon, then you die"),
        (329, "Arrow volley and trampling at Tekaro bridge"),
        (349, "Dakomyd spawning chamber acid death"),
    ],
    "direct_endurance": [
        (37, "Lose 12 END before Chanda combat"),
        (44, "Lose 2 END when the Kazonara hits the boom"),
        (51, "Lose 2 END from the pirate blade"),
        (54, "Lose 2 END from sleeping in the stable"),
        (85, "Lose 2 END from the crossbow graze"),
        (146, "Eat a Meal or lose 3 END"),
        (153, "Lose 5 END from the crossbow bolt"),
        (157, "Restore 1 END and optionally take up to 2 Meals"),
        (164, "Lose 2 END before the OG assassin fight"),
        (171, "Unless Nexus, lose 1 END from the cold river"),
        (174, "Lose 5 END, then go to 234 if alive"),
        (187, "Lose 3 END from the pikes"),
        (191, "Eat a Meal or lose 3 END"),
        (197, "Lose 2 END from the arrow while escaping"),
        (222, "Lose 12 END from the falling Yawshath corpse"),
        (253, "Eat a Meal or lose 3 END during the room/horse/food choice"),
        (266, "Restore 1 END from the ale"),
    ],
    "random_helper": [
        (34, "Pick a number and add 5 to determine purse Gold Crowns", [34]),
        (56, "Random END loss with 0 = 10", [56]),
        (69, "Invisibility adds 5 to the roll", [69]),
        (91, "Random winnings: pick a number and add 5 Gold Crowns", [91]),
        (97, "Straight 3-way ambush branch by roll band", [97]),
        (126, "Straight 3-way gate-charge branch by roll band", [126]),
        (142, "Nexus/Divination -2, Shield -3", [142]),
        (163, "Invisibility +4", [163]),
        (261, "Animal Control +3", [261]),
        (271, "Animal Control or Huntmastery +3", [271]),
        (284, "Two-pick betting game, second pick gets +3, wager tracking", [284]),
        (291, "Straight 2-way branch by roll band", [291]),
        (317, "Divination or Huntmastery -5", [317]),
    ],
    "inventory_currency": [
        (8, "Gain 10 Gold Crowns and optionally take Potion of Laumspur and Map of Varetta", [8]),
        (88, "Gain 5 Gold Crowns from the dead robbers", [88]),
        (111, "Potion of Laumspur: drink now or store in Backpack", [111]),
        (123, "Buy up to 3 Alether Berries at 3 Gold Crowns each", [123]),
        (139, "Gain 11 Gold Crowns and Silver Brooch", [139]),
        (141, "Pay 2 Gold Crowns archery entrance fee", [141]),
        (145, "Gain 12 Gold Crowns and Ruby Ring", [145]),
        (148, "Horse trade: spend either 20 Gold Crowns or 2 Special Items", [212]),
        (160, "Gain the Cess from the youth", [160]),
        (172, "Pay 2 Gold Crowns for food and 3 Gold Crowns for Room 17", [172]),
        (220, "Optional donation of any number of Gold Crowns to Vynar Jupe", [220]),
        (245, "Conundrum stake, win, and loss chain", [245, 50, 62, 113, 223]),
        (276, "OG Nexus route also grants Bronin Warhammer", [276]),
    ],
    "combat_special": [
        (12, "Ignore END you lose in rounds 1-2; may evade anytime"),
        (47, "Bodyguards fight; Bow unusable"),
        (78, "Stop when Roark reaches 11 END and go to 180"),
        (92, "Pirate fight: branch depends on whether combat lasts 3 rounds or less"),
        (114, "Surprise grants +2 CS in round 1 only"),
        (116, "Warhound may be evaded in round 1 only"),
        (155, "First round unarmed at -4 CS; draw weapon round 2; evade after 4 rounds"),
        (156, "Sewer Door resistance combat; may stop and leave"),
        (164, "OG assassin fight: no Bow, no evade, +1 CS if Animal Control"),
        (201, "Town Sergeant fight: any weapon except Bow; branch depends on rounds fought"),
        (208, "Chanda variant with no pre-fight acid hit"),
        (214, "Kalte hunting bow tournament penalty: -4 CS"),
        (215, "River Pirates: evade only after 2 rounds"),
        (254, "Pirates: -2 CS first round unless Huntmastery"),
        (337, "Grave Robbers: evade only in the first round"),
        (343, "Yawshath: can evade only after surviving 3 rounds"),
    ],
}

REVIEW_ITEMS = [
    {
        "section": 24,
        "status": "Design review",
        "note": "Live app keeps the DE-style helper previously requested by the player; OG local text uses a direct branch back to 338 instead of a roll.",
    },
    {
        "section": 112,
        "status": "Intentional DE variant",
        "note": "Herb Pouch storage is intentionally supported even though the OG wording only mentions Backpack storage.",
    },
    {
        "section": 207,
        "status": "Intentional implementation choice",
        "note": "Bronin Warhammer is stored as a weapon-like Special Item rather than a Weapon slot item.",
    },
    {
        "section": 276,
        "status": "Intentional implementation choice",
        "note": "Bronin Warhammer is stored as a weapon-like Special Item rather than a Weapon slot item.",
    },
    {
        "section": 298,
        "status": "Covered indirectly",
        "note": "The Jakan break-on-0 rule is enforced in the section 26 tournament combat flow where the rule actually matters.",
    },
]


def covered(section_or_sections, category: str) -> bool:
    if isinstance(section_or_sections, int):
        section_list = [section_or_sections]
    else:
        section_list = list(section_or_sections)

    if category == "instant_death":
        return all(section in instant_death_sections for section in section_list)
    if category == "direct_endurance":
        return all(section in entry_sections for section in section_list)
    if category == "random_helper":
        return all(section in random_sections or section == 26 for section in section_list)
    if category == "inventory_currency":
        return all(section in entry_sections for section in section_list)
    if category == "combat_special":
        return all(section in combat_sections or section in entry_sections for section in section_list)
    return False


rows = []
category_totals = {}
missing_total = 0
covered_total = 0

for category, items in CANDIDATES.items():
    category_rows = []
    for item in items:
        if len(item) == 2:
            section, cue = item
            coverage_sections = [section]
        else:
            section, cue, coverage_sections = item
        is_covered = covered(coverage_sections, category)
        status = "Covered" if is_covered else "Missing"
        if is_covered:
            covered_total += 1
        else:
            missing_total += 1
        row = {
            "section": section,
            "category": category,
            "cue": cue,
            "coverage_sections": coverage_sections,
            "status": status,
        }
        rows.append(row)
        category_rows.append(row)
    category_totals[category] = {
        "total": len(category_rows),
        "covered": sum(1 for row in category_rows if row["status"] == "Covered"),
        "missing": sum(1 for row in category_rows if row["status"] == "Missing"),
    }

summary = {
    "total_candidates": len(rows),
    "covered": covered_total,
    "missing": missing_total,
    "category_totals": category_totals,
    "review_items": REVIEW_ITEMS,
}

LOG_JSON.write_text(json.dumps({"summary": summary, "rows": rows}, indent=2), encoding="utf-8")

lines = [
    "# Book 6 Automation Audit Refresh",
    "",
    "Date: 2026-04-15",
    "",
    "Comparison target:",
    "- `C:\\Scripts\\Lone Wolf\\modules\\rulesets\\magnakai\\book6.psm1`",
    "- `C:\\Scripts\\Lone Wolf\\modules\\rulesets\\magnakai\\combat.psm1`",
    "- `C:\\Scripts\\Lone Wolf\\modules\\core\\ruleset.psm1`",
    "",
    "## Summary",
    "",
    f"- High-confidence candidates audited: `{summary['total_candidates']}`",
    f"- Covered: `{summary['covered']}`",
    f"- Missing: `{summary['missing']}`",
    "",
    "## Category Totals",
    "",
    "| Category | Total | Covered | Missing |",
    "|---|---|---|---|",
]

for category, totals in category_totals.items():
    label = category.replace("_", " ").title()
    lines.append(f"| {label} | {totals['total']} | {totals['covered']} | {totals['missing']} |")

for category, items in CANDIDATES.items():
    lines.extend([
        "",
        f"## {category.replace('_', ' ').title()}",
        "",
        "| Section | Cue | Coverage | Status |",
        "|---|---|---|---|",
    ])
    for row in rows:
        if row["category"] != category:
            continue
        coverage_label = ", ".join(str(section) for section in row["coverage_sections"])
        lines.append(f"| {row['section']} | {row['cue']} | {coverage_label} | {row['status']} |")

lines.extend([
    "",
    "## Review Items",
    "",
    "| Section | Status | Note |",
    "|---|---|---|",
])

for item in REVIEW_ITEMS:
    lines.append(f"| {item['section']} | {item['status']} | {item['note']} |")

LOG_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(LOG_MD)
print(LOG_JSON)
