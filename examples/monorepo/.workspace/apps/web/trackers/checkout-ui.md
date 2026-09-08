---
type: tracker
status: active
updated: 2026-08-10
epic: checkout-ui
scope: [apps/web]
---

# Checkout UI

| | |
|---|---|
| **Updated** | 2026-08-10 |
| **State** | Address form rebuilt on the new field components; payment step still on the old ones. |
| **Next** | Port the payment step, then delete `LegacyField`. |

This tracker lives in the `apps/web` **sub-workspace** because the work touches nothing
outside `apps/web/`. The search-relevance epic, one level up, spans two packages and so
stays at the root. Both are one workspace, one repository, one `epic:` namespace.

## Items

| # | Item | Status | Notes |
|---|---|---|---|
| 1 | Address form on new fields | done | |
| 2 | Payment step on new fields | active | |
| 3 | Remove `LegacyField` | todo | blocked on 2 |
