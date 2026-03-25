#!/usr/bin/env python3
"""
Extract NPC data from Questie's TBC database for AddressBook addon.
Filters service NPCs (trainers, innkeepers, flight masters, etc.)
and outputs Data.lua in AddressBook format.

Coordinates are 0-100 scale (Questie native format).
Zone names are used instead of mapIDs (resolved at runtime by MapResolver.lua).
"""

import re
import sys
import os
from collections import defaultdict

# Questie TBC npcFlags bitmask values
FLAGS = {
    'VENDOR':        128,
    'FLIGHT_MASTER': 8192,
    'TRAINER':       16,
    'INNKEEPER':     65536,
    'BANKER':        131072,
    'BATTLEMASTER':  1048576,
    'AUCTIONEER':    2097152,
    'REPAIR':        4096,
    'STABLEMASTER':  4194304,
}

# Questie zone IDs -> human-readable zone names
ZONE_NAMES = {
    1: "Dun Morogh",
    3: "Badlands",
    4: "Blasted Lands",
    8: "Swamp of Sorrows",
    10: "Duskwood",
    11: "Wetlands",
    12: "Elwynn Forest",
    14: "Durotar",
    15: "Dustwallow Marsh",
    16: "Azshara",
    17: "The Barrens",
    28: "Western Plaguelands",
    33: "Stranglethorn Vale",
    36: "Alterac Mountains",
    38: "Loch Modan",
    40: "Westfall",
    41: "Deadwind Pass",
    44: "Redridge Mountains",
    45: "Arathi Highlands",
    46: "Burning Steppes",
    47: "The Hinterlands",
    51: "Searing Gorge",
    85: "Tirisfal Glades",
    130: "Silverpine Forest",
    139: "Eastern Plaguelands",
    141: "Teldrassil",
    148: "Darkshore",
    215: "Mulgore",
    267: "Hillsbrad Foothills",
    331: "Ashenvale",
    357: "Feralas",
    361: "Felwood",
    400: "Thousand Needles",
    405: "Desolace",
    406: "Stonetalon Mountains",
    440: "Tanaris",
    490: "Un'Goro Crater",
    493: "Moonglade",
    618: "Winterspring",
    1377: "Silithus",
    1497: "Undercity",
    1519: "Stormwind City",
    1537: "Ironforge",
    1637: "Orgrimmar",
    1638: "Thunder Bluff",
    1657: "Darnassus",
    3430: "Eversong Woods",
    3433: "Ghostlands",
    3483: "Hellfire Peninsula",
    3487: "Silvermoon City",
    3518: "Nagrand",
    3519: "Terokkar Forest",
    3520: "Shadowmoon Valley",
    3521: "Zangarmarsh",
    3522: "Blade's Edge Mountains",
    3523: "Netherstorm",
    3524: "Azuremyst Isle",
    3525: "Bloodmyst Isle",
    3557: "The Exodar",
    3703: "Shattrath City",
    4080: "Isle of Quel'Danas",
}

# Category mapping based on npcFlags and subName patterns
def categorize_npc(flags, sub_name):
    """Returns (category, subcategory) based on flags and subName."""
    sub = (sub_name or "").lower()

    if flags & FLAGS['FLIGHT_MASTER']:
        return ("Transportation", "Flight Masters")
    if flags & FLAGS['INNKEEPER']:
        return ("Services", "Innkeepers")
    if flags & FLAGS['BANKER']:
        return ("Services", "Banks")
    if flags & FLAGS['AUCTIONEER']:
        return ("Services", "Auction Houses")
    if flags & FLAGS['BATTLEMASTER']:
        return ("PvP", "Battlemasters")
    if flags & FLAGS['STABLEMASTER']:
        return ("Services", "Stable Masters")

    if flags & FLAGS['TRAINER']:
        # Distinguish class trainers from profession trainers
        class_keywords = ['warrior', 'paladin', 'hunter', 'rogue', 'priest',
                         'shaman', 'mage', 'warlock', 'druid']
        prof_keywords = ['blacksmith', 'leatherwork', 'tailor', 'engineer',
                        'enchant', 'alchemist', 'alchemy', 'herbalism', 'herb',
                        'mining', 'miner', 'skinning', 'jewel', 'first aid',
                        'cooking', 'fishing', 'inscription']
        weapon_keywords = ['weapon master', 'riding']

        for kw in class_keywords:
            if kw in sub:
                return ("Trainers", "Class Trainers")
        for kw in prof_keywords:
            if kw in sub:
                return ("Trainers", "Profession Trainers")
        for kw in weapon_keywords:
            if kw in sub:
                return ("Trainers", "Weapon & Riding")
        if 'trainer' in sub or 'master' in sub:
            return ("Trainers", "Profession Trainers")
        return ("Trainers", "Other Trainers")

    if flags & FLAGS['REPAIR']:
        if flags & FLAGS['VENDOR']:
            return ("Services", "Repair Vendors")
        return ("Services", "Repair Vendors")

    return None


def parse_npc_entry(line):
    """Parse a single NPC entry line from Questie's format."""
    # Match: [npcID] = {fields...},
    m = re.match(r'^\[(\d+)\]\s*=\s*\{(.+)\},?\s*$', line.strip())
    if not m:
        return None

    npc_id = int(m.group(1))
    content = m.group(2)

    # Extract name (field 1) - first quoted string
    name_m = re.match(r"'([^']*)'", content)
    if not name_m:
        return None
    name = name_m.group(1)

    # Skip internal/debug NPCs
    if '[DND]' in name or '[PH]' in name or '[UNUSED]' in name or '[DNT]' in name:
        return None

    # Extract spawns (field 7) - complex nested table
    # We need to find the spawns table which is after 6 comma-separated fields
    # Fields 1-6: name, minLevelHealth, maxLevelHealth, minLevel, maxLevel, rank
    # Field 7: spawns table {[zoneID]={{x,y},{x,y},...},...}

    # Strategy: walk through the content tracking brace depth
    fields = []
    depth = 0
    current = ""
    i = len(name_m.group(0))  # start after name

    # Skip the comma after name
    while i < len(content) and content[i] in ', ':
        i += 1

    # Parse remaining fields
    field_num = 2  # name was field 1
    current = ""
    for i in range(i, len(content)):
        c = content[i]
        if c == '{':
            depth += 1
            current += c
        elif c == '}':
            depth -= 1
            current += c
        elif c == ',' and depth == 0:
            fields.append(current.strip())
            current = ""
            field_num += 1
        elif c == "'" and depth == 0:
            # Skip quoted strings in other fields
            end = content.find("'", i + 1)
            if end >= 0:
                current += content[i:end+1]
                i = end
            else:
                current += c
        else:
            current += c
    if current.strip():
        fields.append(current.strip())

    # fields[0] = minLevelHealth (field 2)
    # fields[1] = maxLevelHealth (field 3)
    # ...
    # fields[4] = rank (field 6)
    # fields[5] = spawns (field 7)
    # ...
    # fields[7] = zoneID (field 9)
    # ...
    # fields[11] = friendlyToFaction (field 13)
    # fields[12] = subName (field 14)
    # fields[13] = npcFlags (field 15)

    if len(fields) < 14:
        return None

    spawns_raw = fields[5]
    faction_raw = fields[11].strip().strip("'\"")
    sub_name_raw = fields[12].strip().strip("'\"")
    flags_raw = fields[13].strip()

    try:
        npc_flags = int(flags_raw)
    except ValueError:
        return None

    # Parse faction
    faction = None
    if faction_raw == "A":
        faction = "Alliance"
    elif faction_raw == "H":
        faction = "Horde"
    elif faction_raw == "AH":
        faction = None  # Both factions

    # Parse subName
    sub_name = sub_name_raw if sub_name_raw and sub_name_raw != "nil" else None

    # Parse spawns: {[zoneID]={{x,y},{x,y},...},...}
    spawns = {}
    if spawns_raw and spawns_raw != "nil":
        # Find all [zoneID]={{coords}} patterns
        spawn_pattern = re.finditer(r'\[(\d+)\]\s*=\s*\{((?:\{[^}]*\}[,\s]*)+)\}', spawns_raw)
        for sm in spawn_pattern:
            zone_id = int(sm.group(1))
            coords_raw = sm.group(2)
            coords = re.findall(r'\{([\d.]+),([\d.]+)\}', coords_raw)
            if coords:
                # Take first spawn point (most common location)
                x, y = float(coords[0][0]), float(coords[0][1])
                spawns[zone_id] = (x, y)

    return {
        'npcID': npc_id,
        'name': name,
        'flags': npc_flags,
        'faction': faction,
        'subName': sub_name,
        'spawns': spawns,
    }


def main():
    questie_base = "/Volumes/Exine/World of Warcraft/_anniversary_/Interface/AddOns/Questie"
    tbc_db = os.path.join(questie_base, "Database/TBC/tbcNpcDB.lua")

    if not os.path.exists(tbc_db):
        print(f"Error: {tbc_db} not found", file=sys.stderr)
        sys.exit(1)

    # Read and parse
    print("Reading Questie TBC NPC database...", file=sys.stderr)
    with open(tbc_db, 'r') as f:
        content = f.read()

    # Find the data block (after [[return {)
    start = content.find("[[return {")
    if start < 0:
        print("Error: Could not find data block", file=sys.stderr)
        sys.exit(1)

    data_block = content[start + len("[[return {"):]
    end = data_block.rfind("}]]")
    if end >= 0:
        data_block = data_block[:end]

    # Parse each line
    entries = defaultdict(lambda: defaultdict(list))
    total = 0
    matched = 0
    skipped_no_zone = 0

    for line in data_block.split('\n'):
        line = line.strip()
        if not line or not line.startswith('['):
            continue

        total += 1
        npc = parse_npc_entry(line)
        if not npc:
            continue

        cat_result = categorize_npc(npc['flags'], npc['subName'])
        if not cat_result:
            continue

        category, subcategory = cat_result

        # Add entry for each spawn zone
        for zone_id, (x, y) in npc['spawns'].items():
            zone_name = ZONE_NAMES.get(zone_id)
            if not zone_name:
                skipped_no_zone += 1
                continue

            entry = {
                'name': npc['name'],
                'zone': zone_name,
                'x': round(x, 2),
                'y': round(y, 2),
                'faction': npc['faction'],
                'note': npc['subName'],
                'npcID': npc['npcID'],
            }
            entries[category][subcategory].append(entry)
            matched += 1

    print(f"Parsed {total} NPCs, {matched} service NPC entries extracted, {skipped_no_zone} skipped (unknown zone)", file=sys.stderr)

    # Generate Data.lua
    print_data_lua(entries)


def lua_str(s):
    """Escape a string for Lua."""
    if s is None:
        return "nil"
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace("'", "\\'") + '"'


def print_data_lua(entries):
    """Output the Data.lua file."""
    cat_order = ["Trainers", "Transportation", "Services", "PvP"]
    sub_order = {
        "Trainers": ["Class Trainers", "Profession Trainers", "Weapon & Riding", "Other Trainers"],
        "Transportation": ["Flight Masters"],
        "Services": ["Innkeepers", "Repair Vendors", "Banks", "Auction Houses", "Stable Masters"],
        "PvP": ["Battlemasters"],
    }

    print('AddressBook = AddressBook or {}')
    print('')
    print('-- Pre-populated location database extracted from Questie')
    print('-- Coordinates are 0-100 scale (standard WoW map coordinates)')
    print('-- mapID resolved at runtime from zone name via MapResolver.lua')
    print('')
    print('-- Category display order')
    print('AddressBook.CategoryOrder = {')
    for cat in cat_order:
        if cat in entries:
            print(f'    "{cat}",')
    print('}')
    print('')

    print('AddressBook.SubcategoryOrder = {')
    for cat in cat_order:
        if cat not in entries:
            continue
        subs = [s for s in sub_order.get(cat, []) if s in entries[cat]]
        # Add any subcategories not in the predefined order
        for s in sorted(entries[cat].keys()):
            if s not in subs:
                subs.append(s)
        quoted = ', '.join(f'"{s}"' for s in subs)
        print(f'    ["{cat}"] = {{ {quoted} }},')
    print('}')
    print('')

    print('AddressBook.LocationDB = {')

    for cat in cat_order:
        if cat not in entries:
            continue
        print(f'    -----------------------------------------------------------------')
        print(f'    -- {cat.upper()}')
        print(f'    -----------------------------------------------------------------')
        print(f'    ["{cat}"] = {{')

        subs = [s for s in sub_order.get(cat, []) if s in entries[cat]]
        for s in sorted(entries[cat].keys()):
            if s not in subs:
                subs.append(s)

        for sub in subs:
            if sub not in entries[cat]:
                continue
            items = entries[cat][sub]
            # Sort by zone then name
            items.sort(key=lambda e: (e['zone'], e['name']))
            # Deduplicate by name+zone
            seen = set()
            unique = []
            for item in items:
                key = (item['name'], item['zone'])
                if key not in seen:
                    seen.add(key)
                    unique.append(item)

            print(f'        ["{sub}"] = {{')
            for e in unique:
                parts = [f'name = {lua_str(e["name"])}']
                parts.append(f'zone = {lua_str(e["zone"])}')
                parts.append(f'x = {e["x"]}')
                parts.append(f'y = {e["y"]}')
                if e['faction']:
                    parts.append(f'faction = {lua_str(e["faction"])}')
                if e['note']:
                    parts.append(f'note = {lua_str(e["note"])}')
                print(f'            {{ {", ".join(parts)} }},')
            print(f'        }},')

        print(f'    }},')

    print('}')


if __name__ == '__main__':
    main()
