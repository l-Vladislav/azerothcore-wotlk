# Template vs Runtime config — module-wide gotcha

This is the most common confusion when reading docs about this server. It applies to **every module**, not just StatBooster.

## The two layers

| Layer | Path pattern | Role | Ships with |
|---|---|---|---|
| **Template** (`.dist`) | `modules/<Module>/conf/<module>.conf.dist` | Bundled with the module source. Read by no one at runtime. Used as a template when bootstrapping. | Vendor defaults (typically Enable=0) |
| **Runtime** | `env/dist/etc/modules/<module>.conf` (live) and `env/dist/etc-ptr/modules/<module>.conf` (PTR) | What the Docker worldserver actually reads | This fork's tuned values (Enable=1, etc.) |

## Why this matters

- A doc that quotes the `.dist` template is reporting what the *vendor* shipped, not what *this fork* is running.
- `project_statbooster.md` made exactly this mistake — said `Enable = 0` because it looked at the `.dist`.
- AzerothCore's loader prefers `env/dist/etc/modules/*.conf` because that's the mount inside the worldserver container.

## How to check the truth

```bash
# Live realm
grep "^<Key>" env/dist/etc/modules/<module>.conf

# PTR realm
grep "^<Key>" env/dist/etc-ptr/modules/<module>.conf

# Template (rarely useful)
grep "^<Key>" modules/<Module>/conf/<module>.conf.dist
```

## When to edit which

| Goal | Edit |
|---|---|
| Change a live config value | `env/dist/etc/modules/<module>.conf` |
| Change a PTR config value | `env/dist/etc-ptr/modules/<module>.conf` |
| Add a new config key with a sensible default for distribution | `.conf.dist` template (and copy the line into the runtime files) |
| Document a new config key | The `.conf.dist` template (it's the canonical doc) |

## Other modules where this applies

Same pattern for all of these:
- `modules/StatBooster/conf/statbooster.conf.dist` vs `env/dist/etc/modules/statbooster.conf`
- `modules/mod-nemesis-system/conf/mod_nemesis_system.conf.dist` vs `env/dist/etc/modules/mod_nemesis_system.conf`
- `modules/mod-playerbots/conf/playerbots.conf.dist` vs `env/dist/etc/modules/playerbots.conf`
- `modules/mod-ollama-chat/conf/...` vs `env/dist/etc/modules/...`

**Rule of thumb:** if you're being asked "what is X currently set to?", grep the `env/dist/etc/` path, not the `.dist` template.
