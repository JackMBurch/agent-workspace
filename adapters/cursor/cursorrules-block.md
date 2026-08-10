<!--
  Paste the block below into `.cursorrules` at your project root, or into a
  `.cursor/rules/workspace.mdc` file, replacing <WORKSPACE_DIR> with your workspace directory
  name (default `.workspace`).

  Cursor rules are terser than CLAUDE.md or AGENTS.md by convention, so this version is
  compressed to the enforceable rules. The reasoning behind each is in SPEC.md.

  Everything above the horizontal rule is instructions to you and should not be pasted.
-->

---

# Project knowledge base

Plans, trackers, session handoffs and reference docs live in `<WORKSPACE_DIR>/`, a separate git
repository. Never write them into a code repository.

Pick the right type:

- `plans/<epic>/` - how something will be built. Frozen once work starts; corrections go in an
  *Implementation notes* footer.
- `trackers/<epic>.md` - where an epic is up to. Update it in the same turn as the work.
- `sessions/` - what you were doing when you stopped. Write one before stopping mid-task.
- `docs/` - reference material and investigation findings.

A file with checkboxes or a per-item status column is a tracker, not a plan.

Every markdown file starts with frontmatter:

```
---
type: plan | tracker | session | doc
status: active | paused | blocked | review | done | abandoned
updated: YYYY-MM-DD
epic: <slug>
scope: [<repos or packages>]
---
```

`done` and `abandoned` files move to `archive/`. Never delete an abandoned plan: keep it with
`status: abandoned` and one line on why.

After changing anything under `<WORKSPACE_DIR>/`, run:

```
python3 <WORKSPACE_DIR>/bin/build-index.py
```

Name files for their content in kebab-case. No timestamp prefixes, no generated words.
