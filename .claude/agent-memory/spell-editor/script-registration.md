# Registering a C++ spell script

A spell script doesn't run just because the `.cpp` file exists. It must be:
1. Wired into the build via the script loader.
2. Linked to a spell ID via the `spell_script_names` SQL table.

## Steps

### 1. Create the script file

Location depends on which class the spell belongs to:

| Spell class | File |
|---|---|
| Death Knight | `src/server/scripts/Spells/spell_dk.cpp` |
| Druid | `src/server/scripts/Spells/spell_dru.cpp` |
| Hunter | `src/server/scripts/Spells/spell_hun.cpp` |
| Mage | `src/server/scripts/Spells/spell_mage.cpp` |
| Paladin | `src/server/scripts/Spells/spell_pal.cpp` |
| Priest | `src/server/scripts/Spells/spell_pri.cpp` |
| Rogue | `src/server/scripts/Spells/spell_rog.cpp` |
| Shaman | `src/server/scripts/Spells/spell_sha.cpp` |
| Warlock | `src/server/scripts/Spells/spell_warl.cpp` |
| Warrior | `src/server/scripts/Spells/spell_warr.cpp` |
| Cross-class / generic | `src/server/scripts/Spells/spell_generic.cpp` |
| Item-triggered | `src/server/scripts/Spells/spell_item.cpp` |
| Pet abilities | `src/server/scripts/Spells/spell_pet.cpp` |

For a one-off custom spell that doesn't fit, prefer adding it to `spell_generic.cpp` rather than creating a new file (keeps the loader stable).

### 2. Define the script class

Pattern (for a SpellScript, hooks the spell cast):
```cpp
class spell_my_custom_thing : public SpellScript
{
    PrepareSpellScript(spell_my_custom_thing);

    void HandleHit()
    {
        // logic
    }

    void Register() override
    {
        OnHit += SpellHitFn(spell_my_custom_thing::HandleHit);
    }
};
```

For AuraScript (hooks the buff/debuff lifecycle) use `class … : public AuraScript` and `PrepareAuraScript(…)`.

### 3. Register in `AddSC_*` of the same file

At the bottom of `spell_<class>.cpp` there is a function like `void AddSC_<class>_spell_scripts()`. Add your script there:
```cpp
RegisterSpellScript(spell_my_custom_thing);
```

### 4. Make sure `AddSC_*` is declared and called

In `src/server/scripts/Spells/spells_script_loader.cpp`:
```cpp
void AddSC_<class>_spell_scripts();        // declaration
void AddSpellsScripts() {
    ...
    AddSC_<class>_spell_scripts();          // call
}
```
For the standard class files this is already wired — don't add duplicate calls. Only add if you created a *new* `spell_*.cpp` file.

### 5. Link the script to a spell ID (SQL)

In `pending_db_world/`:
```sql
DELETE FROM spell_script_names WHERE spell_id = <id> AND ScriptName = 'spell_my_custom_thing';
INSERT INTO spell_script_names (spell_id, ScriptName) VALUES (<id>, 'spell_my_custom_thing');
```

Delegate this SQL to [[sql-migration-writer]] but provide the exact statements.

### 6. Rebuild

The project is C++ — your change needs `cmake --build` to take effect. User runs the build (do not run `make` from the agent unless explicitly asked). The `spell_script_names` table is hot-reloadable via `.reload spell_script_names` in-game; the C++ side is not.

## Gotchas

- **Negative `spell_id` in `spell_script_names`** = "script applies to all ranks of this spell family". Use sparingly.
- Script name in SQL **must match** the C++ class identifier exactly (case-sensitive).
- If your script doesn't fire, check the worldserver log on startup — missing/orphan script names are warned about.
