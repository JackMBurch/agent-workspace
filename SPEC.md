# agent-workspace specification

**Version 1.0**

The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are to be interpreted as described in
RFC 2119.

Sections 1 to 7 are normative and name no specific tool or vendor. Section 8 maps the spec onto
particular agent tooling and is informative.

---

## 1. Purpose

A workspace is the durable knowledge of a project that is not code and does not belong in a
product repository: how work will be done, where it has got to, what was found, and what state a
person or agent stopped in.

This spec exists because unstructured notes directories fail in four specific, observable ways.
Each requirement below traces to one of them.

**F1. Status is prose, so it cannot be queried.** Notes conventionally carry a status line, and
teams do write them. But free-form values ("in review, PRs ready, waiting on the migration") are
unsortable and uncheckable. The cost is linear: answering "what is live?" means reading every
file. **Addressed by section 4 (frontmatter) and section 5 (a closed vocabulary).**

**F2. Parents go stale the moment a child moves.** An epic file reads `not started` while plans
beneath it are built and shipped. Nothing detects the contradiction, and the epic file is what a
newcomer reads first, so the wrong answer is the one most likely to be believed.
**Addressed by section 7.3 (tracker freshness check).**

**F3. Artifact types are indistinguishable by location.** A written-once spec, a weekly-churning
checklist and a dead investigation share a directory and a naming convention. Their lifecycles
are completely different, and treating one as another is how a closed question gets reopened and
a live checklist goes unread. **Addressed by section 2 (four types) and section 3 (layout).**

**F4. Stopping points have no home.** Handoff notes are written at a project root, or not at all.
The next session reconstructs branch state, what was verified, and what was merely assumed, and
gets it wrong. **Addressed by the `session` type and section 8's park guidance.**

A conforming workspace makes each of these four detectable by a program rather than by diligence.

## 2. Artifact types

There MUST be exactly four types. The boundaries between them are the substance of this spec, so
each is defined by the question it answers and by its lifecycle, not by its content.

| Type | Answers | Written | Lifecycle |
|---|---|---|---|
| `plan` | "how will this be built?" | once, before work starts | frozen once work starts; corrections go in an *Implementation notes* footer |
| `tracker` | "where is this epic up to?" | continuously | updated in the same turn as the work it tracks; the only type expected to churn |
| `session` | "what was I doing when I stopped?" | at a stopping point | write-once, read-once, archived on resume |
| `doc` | "how does this work, or what did we find?" | once | reference; superseded rather than edited |

### 2.1 The plan/tracker test

Confusing a plan with a tracker is the most common failure, because a plan with a checklist at the
bottom looks like a reasonable plan.

> **If a file has checkboxes or a per-item status column, it is a tracker.**

A plan describes an approach and stops being true the moment reality diverges. A tracker describes
current state and is worthless the moment it stops being updated. A single file cannot be both:
freezing it makes the checklist lie, and updating it makes the plan a record of what happened
rather than what was intended.

### 2.2 Frozen plans

A `plan` MUST NOT be rewritten to match what was actually built. Corrections, discovered
constraints and deviations SHOULD be appended in an *Implementation notes* section.

The reason is evidential. A plan edited to match the outcome destroys the record of what was
believed beforehand, which is the only thing that makes a retrospective possible.

### 2.3 Abandoned work is kept

A plan for work that will not be done MUST NOT be deleted. It is marked `abandoned` (section 5)
and moved to `archive/`.

Dead work that reads as live is expensive: a detailed plan behind real committed code is
indistinguishable from a head start, and can consume a full session before someone establishes it
was abandoned. The file is the warning. Deleting it removes the warning and leaves the trap.

## 3. Layout

### 3.1 Structure

A workspace MUST contain a single root directory, referred to here as `$WORKSPACE_DIR`. Its name
is configurable; implementations SHOULD default to `.workspace`.

```
$WORKSPACE_DIR/
  INDEX.md            generated; MUST NOT be hand-edited
  config.toml         optional; defaults apply when absent
  bin/
    build-index.py    generator and validator
  plans/
    <epic>/           plans grouped by epic
    archive/          done and abandoned plans, flat
  trackers/
    <epic>.md         one per epic
    archive/
  sessions/
    <date>-<slug>.md
    archive/          resumed or closed sessions
  docs/
    investigations/   frozen findings that are not work items
```

`plans/`, `trackers/` and `sessions/` MUST each support an `archive/` subdirectory. `docs/` is
exempt: reference material stays where it can be found (section 5.2).

The default name `.workspace` is dot-prefixed to avoid collision with the package-manager meaning
of "workspace" in JavaScript, Rust and Python monorepos, where a top-level `workspace/` directory
is ambiguous and may be picked up by tooling.

### 3.2 The workspace is its own repository

`$WORKSPACE_DIR` MUST be a git repository distinct from the project's code repositories.

Two reasons. First, a plan that spans several repositories has no correct single repository home,
and putting it in one of them makes it invisible from the others. Second, notes churn on a
completely different cadence from code, and mixing them means either polluting the code history or
leaving the notes untracked.

Implementations MUST NOT configure a remote automatically. See section 3.5.

### 3.3 Multi-repo layout

The project root is **not** a git repository; code lives in sibling repositories.

```
project/
  service-api/     (git repo)
  service-web/     (git repo)
  .workspace/      (git repo)
```

No ignore configuration is required, because there is no enclosing repository from which
`$WORKSPACE_DIR` would need to be ignored.

### 3.4 Monorepo layout

The project root **is** a git repository.

```
monorepo/          (git repo)
  packages/
  apps/
  .workspace/      (git repo, nested)
```

The structure is otherwise identical. This is worth stating plainly, because the natural
assumption is that a monorepo needs a different shape. It does not.

A nested repository appears to the enclosing repository as an untracked directory. It therefore
MUST be excluded, or a `git add -A` at the root can commit it as a stray gitlink entry, producing
a broken pseudo-submodule that nobody can clone.

Implementations MUST support excluding via `.git/info/exclude` and MUST default to it.
`.git/info/exclude` is local to the clone and commits nothing. Writing `/.workspace/` into a
shared `.gitignore` publishes to everyone with repository access that the author keeps private
notes at that path, which is a disclosure a tool MUST NOT make on the author's behalf.

Implementations MAY offer writing to the root `.gitignore` as an explicit opt-in, for teams that
have adopted the convention collectively.

### 3.5 Remotes

Implementations MUST NOT create or push to a remote as part of setup.

Working notes are candid by design; that is what makes them useful. In practice they accumulate
customer and partner names, infrastructure detail, measurements taken from production, and
summaries of private conversations. None of it is a credential, and collectively it is a detailed
picture of a business. Publishing it is a decision with a different risk profile from keeping a
local history, and the two MUST NOT be bundled into one action.

## 4. Frontmatter

Every `.md` file under `$WORKSPACE_DIR` MUST begin with a YAML frontmatter block delimited by
`---`, except `INDEX.md`, which is generated.

```yaml
---
type: plan
status: active
updated: 2026-08-10
epic: checkout-v2
scope: [service-api, service-web]
blocked-on: "a sandbox credential from the payments provider"
superseded-by: trackers/checkout-v2.md
---
```

### 4.1 Fields

| Field | Required | Meaning |
|---|---|---|
| `type` | yes | One of the four types in section 2 |
| `status` | yes | One of the values in section 5 |
| `updated` | yes | ISO 8601 date (`YYYY-MM-DD`), absolute, maintained by hand |
| `epic` | no | Slug grouping this file under a tracker |
| `scope` | no | List: repository names in a multi-repo layout, package or app paths in a monorepo |
| `blocked-on` | iff `blocked` | What is being waited on, in plain words |
| `superseded-by` | no | Path to the file that replaced this one |

`updated` MUST be an absolute date. Relative expressions ("last week") are meaningless in a file
read months later, and the staleness check in section 7.2 cannot evaluate them.

`scope` replaces a repository-only field so that the schema covers both layouts. Implementations
SHOULD accept `repos` as a deprecated alias.

### 4.2 Prose status is retained

A file MAY additionally carry a human-readable status header in its body. Implementations MUST
NOT require its removal.

The `status` field exists to be machine-readable; it is deliberately too coarse to explain
anything. The prose header is where the reasoning lives: which pull request is open, what was
verified, which of two things has to land first. Both are needed, and they serve different
readers.

### 4.3 Missing frontmatter is an error

A `.md` file under `$WORKSPACE_DIR` with missing or malformed frontmatter MUST be reported as a
validation error, not silently skipped.

A skipped file is invisible to the index. Invisibility is the exact failure this spec replaces, so
opting out MUST NOT be available by omission.

## 5. Status vocabulary

`status` MUST be one of the following. The set is closed: a value outside it is a validation
error.

| Value | Means | Lives in |
|---|---|---|
| `active` | being worked now, or next up with nothing in the way | live directory |
| `paused` | real work exists and stopped deliberately; resumable | live directory |
| `blocked` | cannot proceed without an external input; `blocked-on:` names it | live directory |
| `review` | built and handed over, waiting on someone else | live directory |
| `done` | shipped, or the question is answered | `archive/` |
| `abandoned` | will not be done; kept as a warning (section 2.3) | `archive/` |
| `needs-triage` | adoption only; type and status not yet established | live directory |

Each definition is intended to be tight enough that two people classify the same file the same
way. The distinction that matters most in practice is `paused` versus `blocked`: `paused` is a
choice you can reverse yourself, `blocked` needs someone else to act. Conflating them hides the
fact that somebody is waiting on you.

### 5.1 Archive correspondence

`done` and `abandoned` files MUST live under an `archive/` directory. Files with any live status
MUST NOT.

This is deliberate redundancy: status is in the metadata *and* in the path. The metadata makes it
queryable; the path makes it obvious to a human scanning the tree and to any tool that lists
filenames without opening them. Either alone leaves a gap.

### 5.2 The `doc` exception

A `doc` with status `done` MAY remain outside `archive/`. Reference material is read rather than
worked, and archiving it makes it hard to find for no benefit. Validators MUST exempt `doc` from
the section 5.1 rule.

### 5.3 `needs-triage`

`needs-triage` is produced only by adoption of pre-existing notes (section 6.7). It MUST always be
reported as a validation failure.

It is not a resting state. It exists so that a mechanical guess about an adopted file can never be
mistaken for a decision somebody made, and so that a half-finished migration cannot be quietly
abandoned: the workspace does not validate until every file has been classified by a human or an
agent that read it.

## 6. Rules

These are the operating rules a conforming workspace is used under. They are addressed to whoever
or whatever writes the files.

**6.1 Update the tracker in the same turn as the work.** Not at the end of the day, not next
session. A tracker that lags behind reality is worse than no tracker, because it is believed. This
is the single rule most worth enforcing in agent guidance.

**6.2 Freeze plans once work starts.** Corrections go in an *Implementation notes* footer
(section 2.2).

**6.3 Never write a plan into a product repository.** It has no correct single home when it spans
several, and repositories frequently ignore notes paths, so a plan written there reads as saved
while being discarded.

**6.4 Name files for their content.** Kebab-case, no timestamp prefixes, no generated or random
words. `coupon-duration-rules.md`, not `2026-08-10-plan-3.md` or `bubbling-conway.md`. The name
SHOULD tell a reader what the file is without opening it. Session files are the one exception and
SHOULD be prefixed with their date, because chronology is the useful ordering for them.

**6.5 Update rather than duplicate.** If a file for the work exists, edit it and bump `updated:`.
A second file on the same subject means two answers to one question, and the reader cannot tell
which is current.

**6.6 Regenerate the index after any change.** `INDEX.md` is generated; a hand-edit is overwritten
and, worse, is trusted until it is.

**6.7 Adopt existing notes rather than starting clean.** Pre-existing notes carry the project's
actual history. Adoption assigns `needs-triage` and forces classification (section 5.3) rather
than assuming a greenfield that does not exist.

## 7. Validation

A conforming implementation MUST provide a validator. It MUST exit non-zero when any check below
fails, and it MUST be runnable without installing dependencies.

Standard library only is a requirement, not a preference. The validator is most needed when a
project is unfamiliar, half-configured, or being picked up after a long gap, which is exactly when
a dependency install is most likely to fail.

### 7.1 Schema checks

1. Frontmatter present and parseable (section 4.3)
2. `type`, `status` and `updated` present
3. `type` within the closed set of section 2
4. `status` within the closed set of section 5
5. `updated` a parseable ISO date
6. `blocked` implies a non-empty `blocked-on`

### 7.2 Staleness

A file with `status: active` whose `updated` date is older than `stale_days` (default 21) MUST
fail. `active` asserts current work; if that has not been true for three weeks, the correct action
is to change the status, and the check forces the choice.

### 7.3 Tracker freshness

For each epic, if a tracker exists and any live plan under that epic has a **more recent**
`updated` date than the tracker, validation MUST fail.

This is the check for F2, and it is the reason the tracker type exists separately at all. It
catches the exact moment a parent goes stale: a child moved, and the summary above it did not.

Additionally, an epic with live files but no tracker SHOULD be reported.

### 7.4 Archive correspondence

Closed status outside `archive/`, or live status inside it, MUST fail, subject to the `doc`
exemption in section 5.2.

### 7.5 Triage

Any `needs-triage` file MUST fail (section 5.3).

### 7.6 Index generation

The generator MUST write `INDEX.md` listing every non-archived file grouped by status, and MUST
mark the file as generated. Archived files SHOULD be summarised by count rather than listed, so
the index stays readable as the archive grows.
