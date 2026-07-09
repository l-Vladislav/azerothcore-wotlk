# Addon zone/pin matching (WorldMap.lua + MapData.lua)

## CRITICAL FACT — GetCurrentMapAreaID() is NOT an AreaTable ID (learned the hard way, 2026-07-05)

**`GetCurrentMapAreaID()` in the 3.3.5a client returns a `WorldMapArea.dbc`
row ID, NOT an `AreaTable.dbc` zone ID.** These are two different, unrelated
numbering spaces (e.g. Darkshore is AreaTable zone 148, but a different
number in WorldMapArea). `nemesis.zoneId` (sent by the server, from
`creature->GetZoneId()`) is always an AreaTable ID.

**Do not compare `GetCurrentMapAreaID()` against `nemesis.zoneId`, or
against anything derived from AreaTable, ever.** A first attempt at fixing
the Wetlands/Darkshore pin bug (below) did exactly this as the PRIMARY
zone-membership check and shipped a regression: cross-ID-space comparisons
produce wrong matches broadly (not a safe no-op), which reportedly broke
the addon for the user across zones, not just the original two. This was
caught by the coordinator/user report, not by in-session testing (no live
3.3.5a client was available to verify the API before shipping — verify
API assumptions like this against real client behavior, or a second
source, before trusting them, especially for anything with "these two
IDs are secretly the same" as its whole premise).

If a numeric client-side zone identifier is ever needed again: there is no
verified-safe way in this session to get an AreaTable-space ID from the
3.3.5a client directly. Use `GetRealZoneText()` (returns the player's own
zone name in client locale — safe, unambiguous, Vanilla-era API) compared
against the server's `nemesis.zoneName` (same AreaTable string, normalized
for ё/е — see below) instead of chasing a numeric ID.

## Current mechanism (since 2026-07-05, second pass — the fix that stuck)

Two DIFFERENT zone-membership questions exist and must NOT share one
implementation:

- **`isNemesisInCurrentZone`** (`WorldMap.lua`) — "is this nemesis in the
  zone the World Map UI is currently DISPLAYING". A player can legitimately
  scroll the map to browse a zone other than their own. This is used for
  actual map PIN rendering (`WM:GetNemesesForCurrentZone`). Matches via
  `GetMapInfo()` (locale-independent internal file name, lowercased) vs
  `MapData:GetZone(nemesis.zoneId, nemesis.zoneName)`'s `byZoneId` table —
  this is the ORIGINAL, pre-regression mechanism, restored as-is. Do not
  add `GetRealZoneText()` here — it always reflects the player's own
  physical location and would incorrectly bleed the player's home-zone
  nemeses onto whatever other zone's map they're browsing.
- **`isNemesisInPlayerZone`** (`WorldMap.lua`) / **`WM.IsNemesisInPlayerZone`**
  (public) — "is this nemesis in the zone I'M PHYSICALLY STANDING IN",
  regardless of what the map UI is showing. Used by the side-panel "This
  Zone" filter and by `BountyBoard.lua`'s "Немезиды в этой зоне" tab
  (switched from `IsNemesisInCurrentZone` — that was the wrong function
  for this tab too). Matches PRIMARILY via `zoneNamesMatch(GetRealZoneText(),
  nemesis.zoneName)` (ё/Ё-normalized string compare — see below), falling
  through to the same `MapData`/`byZoneId` file-name check as a fallback.
  This check is additive-only: a miss always falls through to the existing
  file-name path, never blocks it.

The still-open, never-fully-explained part of the original bug: Wetlands
(11) and Darkshore (148) pins didn't render via the `byZoneId` file-name
path despite the table having correct-looking entries for both, with no
key collisions (verified programmatically). Precedent
(`Aszhara` vs `Azshara`, commit `a2280ef`) suggests a Blizzard internal
map-folder-naming quirk, never confirmed without a live client. The
`isNemesisInPlayerZone`/journal-tab path is now fixed via the
`GetRealZoneText()` string check (verified-safe API); the raw WORLD MAP PIN
case (`isNemesisInCurrentZone`) for these two zones specifically may still
be affected — if reported again, do NOT reach for another numeric-ID
shortcut; verify the true `Interface\WorldMap\<X>\` folder name against an
actual 3.3.5a client/MPQ before changing `byZoneId`.

## What `byZoneId` / `byZoneName` in MapData.lua are actually for now

- `byZoneId`: still the source for `GetTileTexture` (a legacy custom
  full-map tile renderer in `UI.lua`, if that tab is still used) and for
  `navigateToNemesisZone`'s `SetMapZoom` continent/zone-index lookup
  (`buildMapFileToZoom`) — for THOSE two purposes there is no way around
  needing the real folder name, so keep this table complete when adding new
  zones with nemesis spawns.
- `byZoneName` (English zone name → file): dead/legacy in practice. The
  server always sends the AreaTable string for `nemesis.zoneName` (Russian
  when the deployed DBC has ruRU data, English only if that DBC lacks a
  ruRU string for that specific zone). Kept as one more defensive fallback
  layer only. **Do not "fix" a zone by adding an entry here alone** — pin
  rendering falls back to `byZoneId` regardless of whether this table has
  an entry, so adding one here changes nothing for pins.

## AreaTable.csv column-offset trap (dbc-investigator's reference file)

`.claude/dbc/AreaTable.csv` header has 16 name-locale columns
(enUS/enGB/koKR/frFR/deDE/enCN/zhCN/enTW/zhTW/esES/esMX/ruRU/ptPT/ptBR/itIT/Unk)
but the real 3.3.5a `AreaTable.dbc` `LocalizedString` block only has 9 name
slots + a mask (enUS,koKR,frFR,deDE,zhCN,zhTW,esES,esMX,ruRU,mask). The CSV
extractor used the wrong (too-wide) template, so raw values are shifted:
**the actual ruRU zone name string is under the column labeled
`AreaName_zhTW`**, and `AreaName_ruRU`/everything after is blank or reading
unrelated numeric fields (FactionGroupMask etc.). Verified via
`Import-Csv` (which is quote-aware) for zoneId 11/148/1/3/4/8/10/17 — values
match what a naive comma-count read of the raw file also lands on, so the
STRING CONTENT is fine, only the HEADER LABEL is wrong.

Same bug class as `feedback_spell_csv_locale_offset` (documented in user's
global memory) for `Spell_custom.csv` — a recurring pattern in this repo's
DBC-to-CSV extraction tooling. Does not affect the running server (which
reads the real binary DBC via the correct `DBCStructure.h` struct); only
affects anyone/any agent reading `AreaTable.csv` by column name. Flag to
whoever owns the extraction tool if seen again elsewhere.

## Known real DBC content bug (cosmetic, fixed via C++ override, not DBC edit)

Deployed ruRU `AreaTable.dbc` zone 148 (Darkshore) name is "Темные берега"
(missing ё) instead of "Тёмные берега". Fixed via a `zoneNameOverrides`
map inside `NemesisSystem.cpp`'s `GetZoneName()` — NOT by editing the DBC
(no CSV→DBC build pipeline exists in this repo/session; DBC edits are
normally an MPQ-patching job, out of nemesis-dev's toolset). Add more
zoneId entries to that map if more typos are found; do not try to
string-replace generically (risks over-correcting unrelated
declined/subzone strings that legitimately contain the same substring).

## VERIFIED 2026-07-07 (coordinator, from server's own WorldMapArea.dbc via docker cp + struct parse)
- Internal map-folder names (GetMapInfo() namespace) confirmed from the authoritative 3.3.5 WorldMapArea.dbc (108 records):
  - zone 11 Wetlands -> 'Wetlands' (wmaID 40); zone 148 Darkshore -> 'Darkshore' (wmaID 42) — the byZoneId entries were ALWAYS correct for these two.
  - Known-quirky names confirmed: Azshara->'Aszhara' (181), Darnassus->'Darnassis' (381), Elwynn Forest->'Elwynn' (30), Eastern Plaguelands->'EasternPlaguelands' (23).
- ALSO confirmed: WorldMapArea IDs (col 1) are a DIFFERENT numbering space from AreaTable zone IDs (col 3): Wetlands is wmaID 40 but zoneId 11; Darkshore wmaID 42 vs zoneId 148 — hard proof of the GetCurrentMapAreaID() ID-space mismatch behind the 0.2.0 regression.
- Consequence: since byZoneId table + file-name compare are provably correct for Wetlands/Darkshore, the ORIGINAL "no pins in these 2 zones" bug is NOT a table typo. Next suspect: what zoneId/zoneName the server actually sends for nemeses in those zones (subzone-vs-zone id, or name-based path). Instrument the addon or log server-side on next repro.
- Parse recipe: docker cp ac-worldserver-v2:/azerothcore/env/dist/data/dbc/WorldMapArea.dbc + python struct '<4sIIII' header, 11 uint32 fields/record, field 4 = AreaName strref.
