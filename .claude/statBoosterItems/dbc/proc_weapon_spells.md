# Weapon Proc Spells Reference (WotLK 3.3.5)

Proc auras for EQUIP_SPELL weapon enchantments.
All spells verified in Spell.dbc. Names from Wowhead where DBC names are blank.

## How weapon procs work
1. EQUIP_SPELL enchantment applies a **passive aura spell** (Aura 42 = PROC_TRIGGER_SPELL)
2. On melee hit (per ProcTypeMask), there's a % chance to fire
3. The **trigger spell** is the actual effect (damage, buff, debuff, heal)
4. ICD (internal cooldown) prevents spam — defined in trigger spell or proc aura

## ProcTypeMask: 4=melee hit, 20=hit+crit, 40=hit+crit+offhand, 65536=hit taken
## TriggerSchool: 1=phys, 2=holy, 4=fire, 8=nature, 16=frost, 32=shadow, 64=arcane

---

## CLASSIC WEAPON ENCHANT PROCS (verified, safe)

These are the actual proc aura spells behind Classic weapon enchants.
Already used in v2c Fortune pool or suitable for addition.

| Proc Spell | Trigger | Proc% | Effect | School | ICD | Notes |
|---|---|---|---|---|---|---|
| 43929 | 43928 | ~6 PPM | ~40 fire damage | Fire | None | Fiery Weapon. Proc aura triggers 43928 |
| 20004 | - | ~6 PPM | Drain 30 HP from target | Shadow | None | Lifestealing. Direct drain, no trigger spell |
| 20005 | - | ~6 PPM | 30% slow + 25% atk slow 5s | Frost | None | Icy Chill. Direct debuff |
| 20006 | - | ~6 PPM | Shadow dmg + reduce phys dmg 15 | Shadow | None | Unholy Weapon. Direct debuff |
| 20007 | - | ~6 PPM | +100 Str + heal 75-125 for 15s | Holy | None | Crusader. Best Classic melee proc |

---

## ITEM PASSIVE PROCS (Attr=192) — Sorted by type

### Fire Damage Procs
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 9233 | 9057 | 5 | 20 | Fire damage on hit | wotlk.wowhead.com/spell=9233 |
| 15599 | 15598 | 5 | 20 | Fire damage on hit | wotlk.wowhead.com/spell=15599 |
| 18186 | 18187 | 5 | 20 | Fire damage on hit | wotlk.wowhead.com/spell=18186 |
| 29624 | 29638 | 100 | 320 | Fire damage proc | wotlk.wowhead.com/spell=29624 |
| 29625 | 29639 | 100 | 320 | Fire damage proc | wotlk.wowhead.com/spell=29625 |
| 29633 | 29644 | 100 | 320 | Fire damage proc | wotlk.wowhead.com/spell=29633 |

### Shadow Damage Procs
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 7617 | 16783 | 1 | 680 | Shadow damage proc | wotlk.wowhead.com/spell=7617 |
| 7619 | 16784 | 1 | 680 | Shadow damage proc | wotlk.wowhead.com/spell=7619 |
| 9160 | 9159 | 5 | 40 | Shadow damage on hit | wotlk.wowhead.com/spell=9160 |
| 29626 | 29640 | 100 | 320 | Shadow damage proc | wotlk.wowhead.com/spell=29626 |
| 29632 | 29641 | 100 | 320 | Shadow damage proc | wotlk.wowhead.com/spell=29632 |

### Nature Damage Procs
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 13959 | 16782 | 5 | 680 | Nature damage proc | wotlk.wowhead.com/spell=13959 |
| 17332 | 17333 | 5 | 20 | Nature damage on hit | wotlk.wowhead.com/spell=17332 |
| 18979 | 18980 | 5 | 20 | Nature damage on hit | wotlk.wowhead.com/spell=18979 |
| 29634 | 29646 | 100 | 320 | Nature damage proc | wotlk.wowhead.com/spell=29634 |
| 29636 | 29653 | 100 | 320 | Nature damage proc | wotlk.wowhead.com/spell=29636 |
| 29637 | 29655 | 100 | 320 | Nature damage proc | wotlk.wowhead.com/spell=29637 |

### Frost Damage Procs
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 29501 | 29502 | 100 | 320 | Frost damage proc | wotlk.wowhead.com/spell=29501 |

### Holy Damage/Heal Procs
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 16620 | 16621 | 5 | 40 | Holy damage on hit | wotlk.wowhead.com/spell=16620 |
| 23689 | 23682 | 100 | 20 | Holy damage proc | wotlk.wowhead.com/spell=23689 |
| 26605 | 26606 | 100 | 20 | Holy damage proc | wotlk.wowhead.com/spell=26605 |
| 27419 | 27418 | 100 | 4 | Holy proc on hit | wotlk.wowhead.com/spell=27419 |
| 27498 | 27499 | 100 | 4 | Holy proc on hit | wotlk.wowhead.com/spell=27498 |

### Arcane Damage Procs
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 22648 | 22649 | 1 | 4 | Arcane damage on hit | wotlk.wowhead.com/spell=22648 |
| 28752 | 28753 | 100 | 320 | Arcane damage proc | wotlk.wowhead.com/spell=28752 |
| 25767 | 25768 | 15 | 65536 | Arcane damage on hit taken | wotlk.wowhead.com/spell=25767 |
| 25906 | 25907 | 5 | 65536 | Arcane damage on hit taken | wotlk.wowhead.com/spell=25906 |

### Physical Damage Procs
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 7445 | 7423 | 2 | 40 | Physical damage on hit | wotlk.wowhead.com/spell=7445 |
| 7446 | 7447 | 5 | 40 | Physical damage on hit | wotlk.wowhead.com/spell=7446 |
| 7849 | 7848 | 5 | 40 | Physical damage on hit | wotlk.wowhead.com/spell=7849 |
| 21185 | 21186 | 100 | 2 | Physical proc (Maul, Amberseal) | wotlk.wowhead.com/spell=21185 |

### Mana Drain / Restore Procs
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 27522 | 18350 | 100 | 340 | Drain 8 mana, restore 8 mana | wotlk.wowhead.com/spell=27522 |
| 27521 | 32848 | 5 | 81920 | Mana restore proc | wotlk.wowhead.com/spell=27521 |

### Buff-on-Hit Procs (self buff when you hit)
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 23686 | 23687 | 100 | 20 | Nature buff on hit | wotlk.wowhead.com/spell=23686 |
| 23688 | 23684 | 2 | 81920 | Self buff on hit taken | wotlk.wowhead.com/spell=23688 |
| 32837 | 18803 | 15 | 81920 | Self buff proc | wotlk.wowhead.com/spell=32837 |
| 27997 | 27996 | 15 | 81920 | Arcane buff proc | wotlk.wowhead.com/spell=27997 |

### Defensive Procs (on hit taken)
| Proc Spell | Trigger | Proc% | ProcMask | Description | wowhead |
|---|---|---|---|---|---|
| 26119 | 26121 | 20 | 65536 | Nature proc when hit | wotlk.wowhead.com/spell=26119 |
| 26128 | 26129 | 100 | 65536 | Nature proc when hit | wotlk.wowhead.com/spell=26128 |
| 28761 | 28762 | 15 | 65536 | Arcane proc when hit | wotlk.wowhead.com/spell=28761 |
| 28771 | 28772 | 20 | 65536 | Shadow proc when hit | wotlk.wowhead.com/spell=28771 |

---

## PROC_TRIGGER_DAMAGE (Aura 43) — Flat melee damage

Simple flat bonus damage on every melee hit. No trigger spell needed.

| SpellID | Damage | Proc% | Attr | Notes | wowhead |
|---|---|---|---|---|---|
| 34343 | 6 | 101 | 65600 | Low level | wotlk.wowhead.com/spell=34343 |
| 9784 | 8 | 101 | 64 | +8 damage on hit | wotlk.wowhead.com/spell=9784 |
| 38905 | 9 | 101 | 34078720 | +9 damage on hit | wotlk.wowhead.com/spell=38905 |
| 9782 | 16 | 101 | 64 | +16 damage on hit | wotlk.wowhead.com/spell=9782 |
| 16624 | 20 | 101 | 64 | +20 damage on hit | wotlk.wowhead.com/spell=16624 |
| 12099 | 23 | 101 | 64 | +23 damage on hit | wotlk.wowhead.com/spell=12099 |
| 29455 | 26 | 101 | 64 | +26 damage on hit | wotlk.wowhead.com/spell=29455 |
| 12782 | 45 | 101 | 64 | +45 damage on hit | wotlk.wowhead.com/spell=12782 |
| 16550 | 60 | 101 | 262208 | +60 damage on hit | wotlk.wowhead.com/spell=16550 |

---

## QUICK PICKS FOR FORTUNE POOL (Classic-balanced)

### Low tier (T1-T2, iLvl 1-45):
- **43929** — Fiery Weapon (~40 fire damage) — already in v2c
- **20004** — Lifestealing (drain 30 HP) — already in v2c
- **9782** — +16 flat damage on every hit (Aura 43, simple)
- **7445** — 2% chance physical damage proc

### Mid tier (T2-T3, iLvl 26-65):
- **20005** — Icy Chill (slow + atk speed debuff) — already in v2c
- **20006** — Unholy (shadow + phys dmg debuff) — already in v2c
- **9233** — 5% fire damage proc
- **17332** — 5% nature damage proc
- **16620** — 5% holy damage proc

### High tier (T4, iLvl 66-92):
- **20007** — Crusader (+100 Str, heal) — already in v2c
- **23686** — Nature buff on hit (100% proc)
- **29624** — Fire damage proc (100% proc with ICD)

---

## HOW TO VERIFY A SPELL
1. Check wotlk.wowhead.com/spell=XXXXX for tooltip and comments
2. Look at the **trigger spell** too: wotlk.wowhead.com/spell=TRIGGER_ID
3. Test in-game with `.cast SPELL_ID` on a target dummy
