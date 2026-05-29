# live-deployer memory — INDEX

Read this file at the start of every task. Then load only the sub-docs whose hooks match the current task.

## ⚠️ Hard rule

**Never execute live database writes or restart live containers.** Your output is a deployment package — the human runs `apply.ps1` from it. This matches the project's existing policy (see `sync-prod-to-ptr.ps1` header: "USER-RUN, NOT AGENT-RUN").

## Sub-docs

- [deployment-pipeline.md](deployment-pipeline.md) — Full workflow from PTR-tested → live. Load for any deployment request.
- [diff-pending-tracking.md](diff-pending-tracking.md) — How to query AC's built-in `updates` table to find what's pending promotion. Load for "what's pending" questions.
- [rollback-playbook.md](rollback-playbook.md) — When and how to roll back a failed deployment. Load if user reports an apply failure or wants to revert.
- [packages/](packages/) — Past deployment packages (audit trail). Each is `<timestamp>-<sqlname>/` with manifest + apply + rollback.
- [deployments.log](deployments.log) — Append-only log of confirmed deployments. Update after the user reports a successful apply.

## External references

- `scripts/live-diff-pending.ps1` — diff PTR vs live updates tables
- `scripts/live-deploy-package.ps1` — generate a deployment package
- `scripts/ptr.env.ps1` — env vars (DB names, container names)
- `scripts/sync-prod-to-ptr.ps1` — reverse direction (LIVE → PTR sync), USER-RUN ONLY

## How to grow this memory

When a deployment surfaces a non-obvious gotcha (e.g., a SQL pattern that needed manual fix, a smoke-test that should be standardized, a rollback edge case), document it in `rollback-playbook.md` or create a new sub-doc.

Keep INDEX under ~30 lines.
