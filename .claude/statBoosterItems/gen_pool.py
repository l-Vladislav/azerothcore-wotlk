# -*- coding: utf-8 -*-
"""Generate fortune_spell_pool.md with English names and descriptions."""
import csv, re, sys, json

en_names = {
    34939:'Backlash',34917:'Vampiric Touch',34774:'Magtheridon Melee Trinket',34679:'Archmage Vargoth Ritual',
    34657:'Deadly Poison',34404:'Frost Energy',34365:'Ebon Poison',34355:'Poison Shield',
    34241:'Increased Rip Damage',34225:'Frosty Hands',34223:'Fiery Hands',34219:'Recharging Battery',
    49925:'Mystery of the Infinite',49836:'Shock Charge',49791:'Glacier Rot',49281:'Lightning Shield',
    49175:'Improved Icy Touch',48777:'Mount Speed',48776:'Mount Speed',48293:'Flamebringer Chain',
    48160:'Vampiric Touch',47842:'Frost Breath',47574:'Freezing Cloud',47570:'Improved Shadowform',
    64975:'Lightning Charged',64792:'Blood of the Old God',64768:'Lightning Channel',64571:'Blood Draining',
    64436:'Magnetic Core',64350:'Fiery Payback',64021:'Flame Breath',63773:'Lightning Skybeam',
    63756:'Deadly Poison',63632:'Shock Blast',63512:'Frozen Blows',63359:'Shadowform',
    75129:'Shadow Channelling',74939:'Frigid Frostling Aura',74567:'Mark of Combustion',74396:'Fingers of Frost',
    74379:'Shadow Channeling',73422:'Chaos Bane',72998:'Shadow Prison',72350:'Fury of Frostmourne',
    72122:'Frozen Mallet',71367:'Fire Prison',71321:'Frozen Prison',71269:'Vampiric Embrace',
    34598:'Karazhan Caster Robe',34582:'Elemental Response',34401:'Arcane Energy',34294:'Increased Healing Wave',
    34062:'Arcane Repair',33776:'Spiritual Attunement',33713:'Arcane Potency',33297:'Spell Haste Trinket',
    33153:'Artic Flying',33080:'Spirit',33012:'Consume Essence',32796:'Frost Ward',
    49590:'Arcane Disruption',49497:'Spell Deflection',49287:'Arcane Bubble',48837:'Elemental Tenacity',
    48707:'Anti-Magic Shell',48596:'Spirit Dies',48104:'Spirit',48100:'Intellect',
    48074:'Prayer of Spirit',48073:'Divine Spirit',48019:'Arcaneform',47891:'Shadow Ward',
    64999:'Meteoric Inspiration',64700:'Magma Splash',63506:'Improved Flash Heal',61426:'Infinite Spirit',
    61316:'Dalaran Brilliance',61082:'Spirits of the Damned',61024:'Dalaran Intellect',60781:'Curse of Mending',
    60580:'Enchanted',59176:'Spell Damping',58877:'Spirit Hunt',
    73650:'Restore Soul',73572:'Spirit Bomb',72232:'Weakened Spirit',71363:'Summon Spirit',
    71328:'Dungeon Cooldown',70634:'Arcane Channeling',69907:'Arcane Chain Channel',69762:'Unchained Magic',
    68607:'Alluring Perfume Spray',66308:'Call of the Mist',65459:'Spirit Candle',65000:'Meteoric Inspiration',
    34827:'Water Shield',34750:'Badge of the Protector',34381:'Holy Reflection',34206:'Physical Protection',
    33896:'Desperate Defense',33736:'Water Shield',33482:'Shadow Defense',33202:'Reflective Shield',
    33081:'Stamina',
    49871:'Rune of Retribution',49314:'Wyrmrest Defender',49284:'Earth Shield',
    48748:'Absorb Image',48162:'Prayer of Fortitude',48161:'Power Word: Fortitude',48102:'Stamina',
    48066:'Power Word: Shield',46953:'Sword and Board',46804:'Dark Fire Shield',
    64677:'Shield Generator',64413:'Protection of Ancient Kings',64045:'Mind Shield',63489:'Shield of Runes',
    63305:'Grim Reprisal',63119:'Block!',62656:'Dodge Charge',62606:'Savage Defense',
    62147:'Icy Touch Defense',60013:'Earth Shield',59616:'Njord Rune of Protection',59288:'Infra-Green Shield',
    75497:'Zalazane Shield',72590:'Fortitude',71516:'Shadow Infusion',70970:'Hammer Shield',
    70955:'Unbound Plague Protection',70692:'Shield of the Lich King',69926:'Earth Shield',
    69023:'Mirrored Soul',66233:'Ardent Defender',
}

procs = {}
with open('.claude/statBoosterItems/dbc/Spell.csv', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    for row in reader:
        sid = int(row[0])
        if row[69] == '6' and row[93] in ('42','69','85','29','4') and int(row[131] or 0) > 1 and sid > 20000:
            name_ru = row[142]
            desc_ru = (row[176] if len(row) > 176 else '') or (row[193] if len(row) > 193 else '')
            if name_ru:
                procs[sid] = {'name_ru': name_ru, 'desc': desc_ru[:150] if desc_ru else '-', 'aura': row[93], 'icon': int(row[131])}

cats = {
    'WEAPON': (r'урон|огн|лед|тьм|тайн|молн|порази|ожог|яд|удар|крит|скорост|сила атак|ловк|пробив|берсерк|мангуст|палач|вамп|кровь|хаос', 'Offensive procs for weapons'),
    'ARMOR': (r'закл|интелл|дух|маг|мана|восстан|регенер|колд|чар|исцел|mp5', 'Caster/healer procs for armor'),
    'SHIELD': (r'щит|поглощ|отраж|блок|уклон|защит|парир|бронь|выносл|шип|возмезд|стойк', 'Tank/defensive procs for shields'),
}

lines = [
    '# Fortune Pool - Verified Spell IDs (12 per tier per category)',
    '',
    'All spell IDs verified in client Spell.dbc. English names from wowhead.',
    'Each spell needs in-game testing as EQUIP_SPELL enchant before production use.',
    '',
]

for cat, (pattern, desc) in cats.items():
    lines.append('## %s - %s' % (cat, desc))
    lines.append('')
    matches = [(sid, procs[sid]) for sid in procs if re.search(pattern, procs[sid]['name_ru'].lower())]

    tiers = [('T1 (iLvl 1-35)',0,35000),('T2 (iLvl 30-60)',35000,50000),('T3 (iLvl 55-80)',50000,65000),('T4 (iLvl 75+)',65000,999999)]
    for tname, lo, hi in tiers:
        tier = [(s,d) for s,d in matches if lo <= s < hi]
        tier.sort(key=lambda x: -x[0])
        seen = set()
        selected = []
        for sid, data in tier:
            if data['icon'] in seen:
                continue
            seen.add(data['icon'])
            selected.append((sid, data))
            if len(selected) >= 12:
                break

        lines.append('### %s (%d spells)' % (tname, len(selected)))
        lines.append('| Spell | English Name | Description | Aura | Icon |')
        lines.append('|-------|-------------|-------------|------|------|')
        for sid, data in selected:
            en = en_names.get(sid, '(unknown)')
            d = data['desc'].replace('|', '/')
            lines.append('| %d | %s | %s | %s | %d |' % (sid, en, d, data['aura'], data['icon']))
        lines.append('')

lines.append('## Notes')
lines.append('- Aura types: 42=PROC_TRIGGER_SPELL, 4=MOD_DUMMY, 69=ABSORB, 85=MOD_POWER_REGEN, 29=MOD_HEAL')
lines.append('- Some spells may not work as EQUIP_SPELL enchant procs (designed for boss fights etc)')
lines.append('- Spells 71781, 70207, 67258 removed from SHIELD T4 (not found on wowhead)')
lines.append('- Each spell needs in-game testing before adding to production')
lines.append('')

with open('.claude/statBoosterItems/fortune_spell_pool.md', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print('Done - %d total spells' % sum(1 for l in lines if l.startswith('| ') and not l.startswith('| Spell')))
