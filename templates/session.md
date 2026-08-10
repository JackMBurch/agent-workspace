---
type: session
status: paused
updated: <YYYY-MM-DD>
epic: <epic-slug, if any>
scope: [<repos or packages actually touched>]
---

# <What I was doing> - <YYYY-MM-DD>

| | |
|---|---|
| **Stopped because** | <ran out of time / blocked / context switch> |
| **Resumable** | <yes, cleanly / yes, but see the watch-outs / no, see below> |

## The exact next step

<One concrete action. Not "continue the work" - the actual next command, file or decision.
If you cannot name it, the session is not parked yet.>

## State per repo or package

<!-- Gathered from real command output, never from memory. A guessed branch or commit is the
     single most damaging thing a handoff can contain, because the next session trusts it. -->

| Repo / package | Branch | Base | Uncommitted | Unpushed | PR |
|---|---|---|---|---|---|
| <name> | <branch> | <base> | <yes/no> | <n> | <link or none> |

## Verified vs assumed

- **Verified:** <what was actually run or observed, and how>
- **Assumed:** <what was taken on trust and has not been checked>

<!-- Keeping these apart is the point of the section. A fresh session cannot tell the
     difference from the outside, and will treat both as fact. -->

## What would trip up a fresh session

<The non-obvious things: a detached HEAD, a branch that is not what its name suggests, a
migration that must run first, a service that must be up, a decision already taken that the
code does not yet reflect.>
