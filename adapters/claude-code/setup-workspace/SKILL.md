---
name: setup-workspace
description: Set up an agent-workspace in a repository - the plans/trackers/sessions/docs structure, the /park skill, and the CLAUDE.md guidance that makes an agent use them. Use when starting a new repo, when asked to set up or add a workspace, add agent-workspace, bootstrap the notes structure, or adopt an existing notes/docs folder into one.
---

# Set up an agent-workspace

Install the structure a project's non-code knowledge lives in: plans, epic trackers, parked
session state, and reference docs. Spec: https://github.com/JackMBurch/agent-workspace

The failure this prevents: a notes directory where status is prose, parent files go stale
silently, artifact types are mixed, and stopping points have nowhere to go.

## When to use

- Starting a new repository that will be worked on with agents
- Asked to "set up a workspace", "add agent-workspace", "bootstrap the notes structure"
- Adopting an existing `notes/` or `docs/` folder into the structure

**Not** for a repo that already has one. Check for a `.workspace/` (or the name in
`config.toml`) first; if it exists, the job is to use it, not to re-run setup. The one
addition worth making to an existing workspace is a **sub-workspace** (step 3a), when asked
for per-sub-project trackers, a workspace inside a subdirectory, or "one for the root and one
for `<subdir>`".

## Steps

### 1. Locate the agent-workspace clone

The tooling is copied out of a clone, not downloaded per-project. Find it:

```
for d in ~/repos/agent-workspace ~/agent-workspace ~/src/agent-workspace \
         ~/code/agent-workspace ~/.cache/agent-workspace; do
  [ -x "$d/bootstrap.sh" ] && echo "found: $d" && break
done
```

If none exists, clone it once and use that path:

```
git clone https://github.com/JackMBurch/agent-workspace ~/.cache/agent-workspace
```

### 2. Settle the layout before running anything

`bootstrap.sh` picks the layout by asking whether the target is inside a git work tree, and
the two answers are not interchangeable:

- **monorepo** - the target is a repo. The workspace is nested inside it and excluded via
  `.git/info/exclude`, so it commits nothing to the code repo.
- **multi-repo** - the target is a plain directory holding sibling repos. The workspace is a
  root of its own, and there is no enclosing repo to exclude from.

A brand-new repo that has not been `git init`ed yet detects as multi-repo, which is almost
never what was meant. **Run `git init` first if the target is meant to be a single repo.**

In a multi-repo workspace, run setup against the **workspace root**, not a product repo. The
rule that plans never go into a product repo has to be visible from every repo, and guidance
inside one repo is not read while working in another.

### 3. Run setup

```
<CLONE>/adapters/claude-code/setup.sh <TARGET_REPO>
```

Options are passed through to `bootstrap.sh`:

- `--dir NAME` - workspace directory name, default `.workspace`
- `--adopt PATH` - move an existing notes directory in, marking every file
  `status: needs-triage`
- `--ignore-mode gitignore` - monorepo only; write the shared `.gitignore` instead of the
  local `.git/info/exclude`. This is a committed change that tells everyone with repo access
  where notes are kept, so opt in deliberately.

It is idempotent, so re-running to refresh the tooling is safe. It does three things: the
scaffold, the `/park` skill at `.claude/skills/park/SKILL.md`, and the guidance block
appended to the project's `CLAUDE.md`.

Verify all three landed. A scaffold with no guidance block is the common half-install, and it
fails quietly: the structure exists and nothing directs an agent to it, so notes keep landing
at the repo root exactly as before.

### 3a. Sub-workspaces, when a sub-project needs its own

Do not create a second workspace inside the subdirectory. Two workspace repositories is the
problem the spec exists to avoid (a file that belongs to both has a home in neither), and
the spec's answer is one workspace with a **sub-workspace** at the sub-project's own path
(SPEC 3.6):

```
<CLONE>/adapters/claude-code/setup.sh <TARGET_REPO> --sub <sub-project path>
```

That creates `<DIR>/<sub-project path>/{plans,trackers,sessions,docs}`, links
`<sub-project path>/<DIR>` to it, registers it under `subworkspaces` in `config.toml`,
excludes the link from git, and appends the sub-workspace guidance block to the
sub-project's `CLAUDE.md`. Once per sub-project; re-running is safe.

Then move the files that belong to the sub-project alone into it, with `git mv` inside the
workspace repo, and fix any relative links that pointed out of the workspace (they gain the
sub-workspace's depth: `../../servers/x` becomes `../../../../servers/x`). Files about shared
tooling or more than one sub-project stay at the root. `epic:` values need no change - they
are resolved across the whole tree - but `--check` refuses two live trackers for one epic,
so a tracker moves rather than being copied.

### 4. If `--adopt` was used, triage

Every adopted file that did not already declare a type gets `status: needs-triage`, which
**fails `--check` until resolved**. The type guessed from the filename is deliberately weak;
a guess must never be mistaken for a decision.

Read each staged file in `plans/`, set a real `type:` and `status:`, and move it to the
directory that matches. The test: if a file has checkboxes or a per-item status column, it is
a **tracker**, not a plan.

### 5. Write the first tracker

Setup is not finished at a working validator. An empty workspace is not yet used by anything,
and the type that carries the value is the tracker.

```
cp <DIR>/templates/tracker.md <DIR>/trackers/<epic>.md
```

Fill in the epic name, the one-line state, and the single next action. Then:

```
python3 <DIR>/bin/build-index.py
```

### 6. Report what to do differently from now on

Say these three things plainly, because they are what the structure depends on:

- **The tracker is updated in the same turn as the work it tracks.** A tracker that lags is
  worse than no tracker, because it is believed.
- **Park with `/park`** rather than leaving state in your head or at the repo root.
- **The notes repo has no remote, deliberately.** Local history is the undo and the record.
  Pushing is a separate outward-facing decision: working notes are candid by design and
  accumulate customer names, infrastructure detail, and private conversation summaries.
