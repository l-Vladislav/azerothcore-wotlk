#!/usr/bin/env python3
"""Generate app/data/spell_enums.json from the core's own headers.

The spell editor offers every aura, effect, target and attribute flag the
server actually understands. Hand-listing them would rot the moment the core
is synced upstream, so the catalogue is parsed out of the headers instead:

    src/server/game/Spells/Auras/SpellAuraDefines.h   AuraType
    src/server/shared/SharedDefines.h                 the rest

Run it after an upstream sync; the JSON is committed so the container does not
need the core sources.

    python tools/admin-panel/scripts/gen_spell_enums.py
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PANEL = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(PANEL))

AURA_H = os.path.join(REPO, "src", "server", "game", "Spells", "Auras",
                      "SpellAuraDefines.h")
SHARED_H = os.path.join(REPO, "src", "server", "shared", "SharedDefines.h")
OUT = os.path.join(PANEL, "app", "data", "spell_enums.json")

# enum name -> key in the JSON. Order is the order the editor shows them in.
WANTED = [
    (SHARED_H, "SpellEffects", "effects"),
    (SHARED_H, "Targets", "targets"),
    (SHARED_H, "Mechanics", "mechanics"),
    (SHARED_H, "DispelType", "dispel"),
    (SHARED_H, "SpellSchools", "schools"),
    (SHARED_H, "SpellSchoolMask", "school_mask"),
    (SHARED_H, "Powers", "powers"),
    (SHARED_H, "Stats", "stats"),
    (SHARED_H, "SpellDmgClass", "dmg_class"),
    (SHARED_H, "SpellPreventionType", "prevention"),
    (SHARED_H, "SpellAttr0", "attr0"),
    (SHARED_H, "SpellAttr1", "attr1"),
    (SHARED_H, "SpellAttr2", "attr2"),
    (SHARED_H, "SpellAttr3", "attr3"),
    (SHARED_H, "SpellAttr4", "attr4"),
    (SHARED_H, "SpellAttr5", "attr5"),
    (SHARED_H, "SpellAttr6", "attr6"),
    (SHARED_H, "SpellAttr7", "attr7"),
]

ENTRY = re.compile(r"^\s*([A-Z][A-Z0-9_]*)\s*(?:=\s*([^,]+?))?\s*,?\s*(?://.*)?$")


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def enum_body(source: str, name: str) -> str:
    """Text between the braces of `enum <name>`, tolerating `: uint32` etc."""
    match = re.search(r"\benum\s+(?:class\s+)?" + re.escape(name) +
                      r"\b[^{;]*\{", source)
    if not match:
        raise SystemExit("enum %s not found" % name)
    start = match.end()
    depth = 1
    index = start
    while depth and index < len(source):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
        index += 1
    return source[start:index - 1]


def parse_value(expr: str, known: dict) -> int | None:
    """Evaluate the small subset of C++ that appears in these enums."""
    expr = expr.strip().rstrip(",").strip()
    if not expr:
        return None
    expr = re.sub(r"\b(0x[0-9A-Fa-f]+|\d+)[uUlL]+\b", r"\1", expr)
    # Bare identifiers refer to earlier entries in the same enum.
    for ident in set(re.findall(r"\b[A-Z][A-Z0-9_]*\b", expr)):
        if ident in known:
            expr = re.sub(r"\b%s\b" % ident, str(known[ident]), expr)
        else:
            return None
    if not re.fullmatch(r"[0-9xXa-fA-F()+\-*|&<>~ ]+", expr):
        return None
    try:
        return int(eval(expr, {"__builtins__": {}}, {}))  # noqa: S307
    except Exception:
        return None


# Symbols accumulate across enums: SpellSchoolMask is written in terms of
# SpellSchools, so a per-enum table would silently drop every masked entry.
SYMBOLS: dict[str, int] = {}


def parse_enum(path: str, name: str) -> list[dict]:
    source = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    body = enum_body(source, name)
    out, known, nxt = [], SYMBOLS, 0
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = ENTRY.match(line)
        if not match:
            continue
        ident, expr = match.group(1), match.group(2)
        value = parse_value(expr, known) if expr else nxt
        if value is None:
            continue
        known[ident] = value
        nxt = value + 1
        out.append({"id": value, "const": ident, "label": pretty(ident, name)})
    return out


PREFIXES = ("SPELL_AURA_", "SPELL_EFFECT_", "TARGET_", "MECHANIC_",
            "DISPEL_", "SPELL_SCHOOL_MASK_", "POWER_", "STAT_",
            "SPELL_DAMAGE_CLASS_", "SPELL_PREVENTION_TYPE_")


def pretty(ident: str, enum_name: str) -> str:
    """Human label: drop the enum's prefix, lowercase, keep it recognisable."""
    label = ident
    if enum_name.startswith("SpellAttr"):
        label = re.sub(r"^SPELL_ATTR\d+_", "", label)
    else:
        for prefix in PREFIXES:
            if label.startswith(prefix):
                label = label[len(prefix):]
                break
    label = label.replace("_", " ").strip().lower()
    return label[:1].upper() + label[1:] if label else ident


def main() -> None:
    for path in (AURA_H, SHARED_H):
        if not os.path.isfile(path):
            raise SystemExit("core header missing: %s — run from the repo" % path)

    data = {"auras": parse_enum(AURA_H, "AuraType")}
    for path, enum_name, key in WANTED:
        data[key] = parse_enum(path, enum_name)

    # Attribute flags are eight separate 32-bit fields; the editor shows them
    # as one list of checkboxes per field, so keep the field name with them.
    data["attr_fields"] = ["attr%d" % i for i in range(8)]

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=1, sort_keys=False)
        handle.write("\n")

    print("wrote %s" % OUT)
    for key, rows in data.items():
        if isinstance(rows, list) and rows and isinstance(rows[0], dict):
            print("  %-13s %4d" % (key, len(rows)))


if __name__ == "__main__":
    sys.exit(main())
