<!--
  Paste the block below into your project's AGENTS.md, replacing <WORKSPACE_DIR> with your
  workspace directory name (default `.workspace`).

  AGENTS.md is read by Codex and a growing number of other agent tools. If your project has no
  AGENTS.md, create one at the project root with this as its first section.

  Everything above the horizontal rule is instructions to you and should not be pasted.
-->

---

## Working knowledge: plans, trackers, sessions, docs

All durable project knowledge that is not code lives in `<WORKSPACE_DIR>/`, a git repository
separate from the code. Read `<WORKSPACE_DIR>/README.md` before writing there.

**Four artifact types. Choose deliberately:**

| Type | Answers | Where | Lifecycle |
|---|---|---|---|
| plan | how will this be built? | `<WORKSPACE_DIR>/plans/<epic>/` | frozen once work starts |
| tracker | where is this epic up to? | `<WORKSPACE_DIR>/trackers/<epic>.md` | updated in the same turn as the work |
| session | what was I doing when I stopped? | `<WORKSPACE_DIR>/sessions/` | write-once, archived on resume |
| doc | how does this work / what did we find? | `<WORKSPACE_DIR>/docs/` | reference; superseded, not edited |

If a file has checkboxes or a per-item status column, it is a tracker, not a plan.

**Rules:**

1. Every markdown file starts with frontmatter: `type`, `status`, `updated` (ISO date), plus
   optional `epic`, `scope`, `blocked-on`, `superseded-by`. A file without it is invisible to
   the index and fails validation.
2. `status` is one of `active`, `paused`, `blocked`, `review`, `done`, `abandoned`. `done` and
   `abandoned` files move to an `archive/` directory.
3. Update the epic's tracker in the same turn as the work it tracks. A tracker that lags is
   worse than none, because it is believed.
4. Plans are frozen once work starts. Corrections go in an *Implementation notes* footer, not
   by rewriting the plan to match the outcome.
5. Never write a plan into a code repository.
6. Name files for their content, kebab-case, no timestamps or generated words.
7. After any change: `python3 <WORKSPACE_DIR>/bin/build-index.py`. Validate with `--check`.
8. Before stopping mid-task, write a session file from
   `<WORKSPACE_DIR>/templates/session.md`. Record the exact next step, and keep "verified" and
   "assumed" apart.
