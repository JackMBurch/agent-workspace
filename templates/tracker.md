---
type: tracker
status: active
updated: <YYYY-MM-DD>
epic: <epic-slug>
scope: [<repo-or-package>]
---

# <Epic name>

| | |
|---|---|
| **Updated** | <YYYY-MM-DD> |
| **State** | <one line: what is happening right now> |
| **Next** | <the single next action> |

<!--
  This file is updated in the SAME TURN as the work it tracks (SPEC 6.1). A tracker that lags
  is worse than no tracker, because it is believed.

  The validator enforces one half of this: if a plan under this epic has a more recent
  `updated:` date than this file, `--check` fails.
-->

## Items

| # | Item | Status | Notes |
|---|---|---|---|
| 1 | <item> | open / in progress / review / done / dropped | <PR, blocker, decision> |

## Open questions

| Question | Asked | Waiting on | Blocks |
|---|---|---|---|
| <question> | <YYYY-MM-DD> | <who> | <which items> |

## Plans under this epic

<!-- Link the plan files. The plans hold the how; this file holds the where-it-got-to. -->

- [`<plan-file>.md`](../plans/<epic-slug>/<plan-file>.md) - <one line>

## Log

<!-- Newest first. Dated one-liners. This is what makes the tracker auditable rather than
     just current: a reader can see when something changed, not only that it did. -->

- **<YYYY-MM-DD>** - <what changed>
