# Loud ambient (looping) sounds on pet models — diagnosis + fix

Some displayIds carry a **looping ambient sound** (fire crackle, rumble) that plays
the whole time the pet is summoned. Server has NO control over it — it's client DBC.

## Mechanism

`CreatureDisplayInfo.dbc` (our `CreatureDisplayID`) → field `SoundID`:
- `SoundID != 0` → that `CreatureSoundData.dbc` row; its **`LoopSoundID`** is the ambient loop.
- `SoundID == 0` → model-default kit from `CreatureModelData.dbc` (loop may be baked there).

Local exports (2026-06-05, from owner's client): `.claude/dbc/CreatureDisplayInfo.csv`,
`.claude/dbc/CreatureSoundData.csv`, `.claude/dbc/CreatureModelData.csv` (CMD.SoundID =
the model-default kit — REQUIRED to judge SoundID=0 displays).

## Known kit verdicts (definitive, 2026-06-05)

| Model | Default kit → Loop | Verdict |
|---|---|---|
| Imp (371) | 348 → **10721** | Standard warlock-imp ambient, quiet — acceptable. The LOUD one is kit 1688 (Loop **1454**) on display 12190 only. |
| Fire elemental (160) | 158 → **1454** | ALL displays of this model crackle loudly (8409 has explicit kit 2586 → 12342). No quiet stock variant — option C or other model. |
| Ragnaros (1571) | 1508 → **7556** | Loud rumble, both displays. |
| XS-001 (3112, display 29060) | 2925 → **15361** | Machine hum; single display of the model, no twin. |
| Lil' XT (32031) | CDI kit 3107 → 0 | Clean — Blizzard gave the PET version an explicit loop-less kit. |

## Fix ladder

1. **Quiet visual twin (server-only, try FIRST).** Same `ModelID` often has many displays;
   look for one with identical `TextureVariation_1` + `CreatureModelScale` + `ParticleColorID`
   but `SoundID=0` (or a kit with `LoopSoundID=0`). Swap `displayId` in the family JSON →
   regenerate → apply. No MPQ. DisplayId travels in the spawn packet — resummon shows it,
   no WDB clear needed.
   - Proven: Flame Imp **12190** (SoundID=1688, Loop=1454 fire crackle) → twin **10817**
     (scale 1.5, ImpSkinRed, particle 339, SoundID=0). Used for fire 2.1/2.2.
2. **Different model** — owner picks another npc (used for Ragnaros 2.10: model-default
   loop, no quiet display variant of model 1571 exists).
3. **Custom CDI row (option C — IMPLEMENTED 2026-06-05 as `muteAmbient`).** Set
   `"muteAmbient": true` on the pet in the family JSON. Generator then:
   - SQL uses custom displayId = **65000 + (F-1)*10 + (P-1)** (range 65000+ free in both
     CDI and CSD; CDI max stock 32754, CSD max 3108) + copies bounding into
     `creature_model_info` from the source display.
   - `-Csv` writes clone rows to `.claude/dbc/CreatureDisplayInfo_custom.csv` /
     `CreatureSoundData_custom.csv`: CDI clone with `SoundID`→custom kit; kit = clone of
     the EFFECTIVE kit (CDI.SoundID or CMD default) with `LoopSoundID=0` (death/idle kept).
   - CDI.SoundID override wins over model-default — works for model-default loops too.
   **Deploy order matters:** owner merges the custom rows (WDBX) into
   `CreatureDisplayInfo.dbc` + `CreatureSoundData.dbc` for the client MPQ **and**
   `CreatureDisplayInfo.dbc` into the SERVER's dbc data dir FIRST — the worldserver
   validates `creature_template_model.CreatureDisplayID` against its DBC store and
   SKIPS unknown ids (pet would spawn modelless). Only then apply SQL + restart.
   In use: 65008 (mech 1.9, src 29060), 65016 (fire 2.7, src 8409), 65019 (fire 2.10,
   src 18139 Abyssal Flamebringer — Ragnaros dropped: loud model loop + giant M2 fire
   animation that does not scale, unfixable via DBC).

   **SERVER DBC LOCATION GOTCHA (hit + solved 2026-06-05):** PTR worldserver reads
   data from a docker NAMED VOLUME mounted RO at `/azerothcore/env/dist/data/` —
   there is NO host folder behind it; replacing files on the host changes nothing.
   The REAL volume name is compose-prefixed: **`azerothcore-wotlk_ac-client-data-v2`**
   (compose file says `ac-client-data-v2`; `docker run -v ac-client-data-v2:...` with
   the bare name silently CREATES a stray empty volume — find the true name via
   `docker inspect ac-worldserver-ptr --format '{{range .Mounts}}...'`). To update:
   1. Owner drops the patched binary `.dbc` (the same files that went into the MPQ —
      server reads loose extracted DBCs, never MPQs) into `.claude/dbc/patched/`.
   2. `docker run --rm -v azerothcore-wotlk_ac-client-data-v2:/data -v "<repo>/.claude/dbc/patched:/src:ro" alpine sh -c "cp /src/*.dbc /data/dbc/"`
      (worldserver's mount is :ro, but the volume itself is writable).
   3. `scripts/ptr-restart.ps1`, then verify.
   **Verification:** symptom logs as "Table creature_model_info has model for not
   existed display id (NNNNN)" right after "Loading Creature Model Based Info Data..."
   (often only in owner console, NOT in Server.log/Errors.log). Definitive checks:
   - Server.log: the "Loaded NNN Creature Model Based Info" line with no error after it.
   - `docker cp` the DBC out and byte-scan LE uint32 of the custom id (65008 = F0 FD 00 00).
   - Patched size delta: CDI +64 bytes/record (stock 24262 rec, 1610064 B), CSD +152/record.
   Owner mental-model note: spells work via the `spell_dbc` DB TABLE override, but most
   DBCs (CreatureDisplayInfo included) have NO DB override in AC — file-only.

## Check-before-ship rule

When picking any new pet model, check its display row for `SoundID != 0` with a non-zero
`LoopSoundID` — flag loud candidates to the owner BEFORE applying.
