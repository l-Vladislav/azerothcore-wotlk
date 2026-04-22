# Consistency Check

Run after any pool change.

## Counts per tier

```bash
for tier in T1 T2 T3 T4; do
  md_p3=$(grep -oE '^\| 9[0-9]{4}' .claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_${tier}.md | sort -u | wc -l)
  sql_p3=$(grep -cE "^\(9" data/sql/updates/pending_db_world/statbooster_pool3_${tier}.sql)
  md_p4=$(grep -oE '9[0-9]{4}' .claude/statBoosterItems/pools/fortune_pool/fortune_${tier}.md | grep '^900' | sort -u | wc -l)
  sql_p4=$(grep -cE "^\(9" data/sql/updates/pending_db_world/statbooster_pool4_${tier}.sql)
  echo "${tier}: Pool3 MD=${md_p3} SQL=${sql_p3} | Pool4 MD=${md_p4} SQL=${sql_p4}"
done

docker compose exec ac-database mysql -uroot -ppassword acore_world -e "
  SELECT PoolGroup, CONCAT(iLvlMin,'-',iLvlMax) AS tier, COUNT(*)
  FROM statbooster_enchant_template WHERE PoolGroup IN (3,4)
  GROUP BY PoolGroup,iLvlMin,iLvlMax ORDER BY PoolGroup,iLvlMin;"
```

Expected: T1=8/30, T2=8/33, T3=8/35, T4=8/34 (Pool 3/Pool 4).

## Base covers tier

Every tier enchant ID must exist in the matching `_base.sql`:

```bash
for t in T1 T2 T3 T4; do
  b=$(grep -oE '\(9[0-9]{4}' data/sql/updates/pending_db_world/statbooster_pool4_${t}_base.sql | sed 's/(//' | sort -u)
  t4=$(grep -oE '^\(9[0-9]{4}' data/sql/updates/pending_db_world/statbooster_pool4_${t}.sql | sed 's/(//' | sort -u)
  echo "${t}: $(comm -23 <(echo "$t4") <(echo "$b") || echo OK)"
done
```

## Custom spell refs

```bash
docker compose exec ac-database mysql -uroot -ppassword acore_world -e "
  SELECT e.ID, e.EffectArg_1 FROM spellitemenchantment_dbc e
  LEFT JOIN spell_dbc s ON e.EffectArg_1 = s.ID
  WHERE e.ID BETWEEN 90001 AND 90137 AND e.EffectArg_1 >= 100000 AND s.ID IS NULL;"
```

Expected: empty.

## Missing proc data

```bash
docker compose exec ac-database mysql -uroot -ppassword acore_world -e "
  SELECT e.ID FROM spellitemenchantment_dbc e
  LEFT JOIN spell_enchant_proc_data p ON e.ID = p.entry
  WHERE e.ID BETWEEN 90001 AND 90137 AND e.Effect_1 = 1 AND p.entry IS NULL;"
```

Expected: empty.

## Addon coverage

Every enchant ID in `statbooster_enchant_template` should have a `[id] = "..."` entry in `EnchantDB.lua`.
