# Workflow

## Rule

MD edit → regenerate SQL → apply to DB → update addon/client → restart server.

## Add/change an enchant

1. Edit MD: `pools/<pool>/T<N>.md` — add/remove rows in slot sections. Mask is auto-computed from slot presence.
2. Regenerate tier SQL from MD (scripts in `/tmp/` during sessions).
3. Apply: `docker compose exec ac-database mysql -uroot -ppassword acore_world < <file>` for `pool4_T<N>_base` then `pool4_T<N>` (or pool3 equivalents).
4. Addon: add enchant ID → Russian name in `EnchantDB.lua`.
5. Client MPQ: add row to `Spell_custom16.csv` or `SpellItemEnchantment_custom.csv` if new IDs; rebuild MPQ; deploy.
6. Restart: `docker compose restart ac-worldserver`.

## Change a custom spell value (duration, cooldown, radius, attributes)

1. `UPDATE spell_dbc SET ... WHERE ID = <id>` in DB.
2. Regenerate `pool4_T<N>_base.sql` from DB (so rebuild picks it up).
3. Update matching field in `Spell_custom16.csv`.
4. Restart worldserver.

## Remove an enchant

Remove from MD everywhere → regenerate SQL → apply → remove from `EnchantDB.lua` → restart.

## Avoid these

- Editing SQL directly without updating MD (next regen from MD overwrites).
- `DELETE BETWEEN 90001 AND 90105` — hits Pool 3 IDs 90100+. Narrow Pool 4 to 90001-90090.
- Changing server `spell_dbc` without matching client CSV → wrong tooltip/timer.
- Not restarting after DBC change (it's cached at startup).
