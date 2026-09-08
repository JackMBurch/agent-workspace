# agent-workspace

A structure for the knowledge a project accumulates that is not code: plans, epic trackers,
parked session state, and reference docs. Designed for projects worked on with coding agents,
where "what is in flight right now?" has to be answerable without reading thirty files.

Works with a **multi-repo** workspace or a **monorepo**. The structure is identical in both; only
the ignore wiring differs.

## The problem

Notes directories fail the same way everywhere:

1. **Status is prose.** Files carry a status line, so the convention is being followed. But the
   values are free-form sentences, so nothing can be filtered, sorted, or checked. Answering
   "what is live?" means opening every file.
2. **Parents go stale silently.** An epic file says `not started` while three plans under it are
   half-built. Nothing detects the contradiction, and the epic file is the one a newcomer reads
   first.
3. **Artifact types get mixed.** Specs, live checklists, and frozen investigations share a
   directory and look identical. A spec is written once; a checklist churns weekly; an
   investigation is dead. Same folder, no signal.
4. **Stopping points have nowhere to go.** Handoffs get written at the project root, or not at
   all, and the next session reconstructs state by guessing.

## The shape

```
.workspace/                  name is configurable
  INDEX.md                   generated - never hand-edited
  config.toml
  bin/build-index.py         generates the index; --check validates
  plans/
    <epic>/                  plans grouped by epic
    archive/                 done and abandoned
  trackers/                  one per epic, the live state
  sessions/                  parked session handoffs
  docs/
    investigations/          frozen findings that are not work items
  <sub-project path>/        optional sub-workspace: the same four directories, scoped to
                             one sub-project, with its own INDEX.md
```

Every markdown file starts with frontmatter:

```yaml
---
type: plan | tracker | session | doc
status: active | paused | blocked | review | done | abandoned
updated: 2026-08-10
epic: checkout-v2
scope: [service-api, service-web]
---
```

That is what makes the index generable and the staleness checks possible. A file without
frontmatter is a `--check` error, not a skip: a file that opts out is invisible, which is the
failure this replaces.

## Quick start

```
git clone https://github.com/JackMBurch/agent-workspace
cd /path/to/your/project
/path/to/agent-workspace/bootstrap.sh
```

Bootstrap detects whether you are in a monorepo or a multi-repo workspace, creates the structure,
copies the tooling in, initialises a git repo for your notes, wires the ignore, and validates the
result before it exits.

Adopting an existing notes folder:

```
/path/to/agent-workspace/bootstrap.sh --adopt ./notes
```

Every adopted file gains frontmatter with `status: needs-triage`, which **fails `--check` until
resolved**. The type it guesses from the filename is deliberately weak; the point is that a guess
can never be mistaken for a decision.

The tooling is **copied into your project**, not linked. Once bootstrapped, your project has no
dependency on this repo.

A project with distinct sub-projects - servers in a homelab repo, services in a monorepo - can
give each one a **sub-workspace**: a slice of the same workspace, at the same relative path,
with its own trackers, sessions and docs and its own `INDEX.md`:

```
/path/to/agent-workspace/bootstrap.sh --sub servers/jellyfin
```

That creates `.workspace/servers/jellyfin/`, links `servers/jellyfin/.workspace` to it so the
usual relative paths work from inside the sub-project, registers it in `config.toml`, and
excludes the link. Epics are shared across the whole tree, so a plan in the sub-workspace can
hang off a tracker at the root; the root `INDEX.md` lists everything and says where each file
lives. One workspace repository, not one per sub-project. Spec section 3.6.

If you work with Claude Code, do the whole setup in one command instead - scaffold, `/park`
skill and agent guidance together:

```
/path/to/agent-workspace/adapters/claude-code/setup.sh /path/to/your/project
```

See [`adapters/claude-code/`](adapters/claude-code/) for what that installs and how to get a
global `/setup-workspace` skill for future repos.

## Using it

```
python3 .workspace/bin/build-index.py            # regenerate INDEX.md
python3 .workspace/bin/build-index.py --check    # validate only, non-zero exit on a problem
```

`--check` rejects: missing or invalid frontmatter; an `active` file untouched past the staleness
limit; an epic tracker older than a plan beneath it; `blocked` with no `blocked-on:`; a live file
in `archive/` or a closed one outside it; and any unresolved `needs-triage`.

Standard library only, on purpose. It has to keep working when nothing else does.

## Agent guidance

The structure only holds if agents follow it. `adapters/` has paste-ready blocks:

| Tool | File |
|---|---|
| Claude Code | [`adapters/claude-code/`](adapters/claude-code/) - guidance block, a `/park` skill, and a `setup.sh` that installs both |
| Codex and generic | [`adapters/codex/`](adapters/codex/) - `AGENTS.md` block |
| Cursor | [`adapters/cursor/`](adapters/cursor/) - `.cursorrules` block |

The single most important rule to install: **the tracker is updated in the same turn as the work
it tracks.** A tracker that lags is worse than no tracker, because it is believed.

## Documents

- **[SPEC.md](SPEC.md)** - the normative spec. Read this if you are implementing or extending.
- **[examples/](examples/)** - worked examples for both layouts. Fictional projects.

This repo uses its own spec: bootstrap has been run against it, so a `.workspace/` exists here
holding this project's own tracker and plan. You will not find it in the file listing, because
the monorepo rule excludes it via `.git/info/exclude` and it is never pushed. That is the spec
working as designed rather than an omission - and it is why `examples/` exists as the public
demonstration.

## Backup and privacy

Bootstrap runs `git init` and adds **no remote**, deliberately. Local history gives you the undo
and the record, which is most of the value. Pushing is a separate, outward-facing decision:
working notes are candid by design and tend to accumulate customer names, infrastructure detail
and private conversation summaries. If you add a remote, consider whether it should be private,
and who "everyone with access" turns out to mean.

## Licence

MIT. See [LICENSE](LICENSE).
