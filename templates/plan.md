---
type: plan
status: active
updated: <YYYY-MM-DD>
epic: <epic-slug>
scope: [<repo-or-package>]
---

# <What this builds>

| | |
|---|---|
| **Created** | <YYYY-MM-DD> |
| **Status** | <One line of narrative. Which branch, which PR, what is waiting on what.> |
| **Scope** | <repos or packages touched> |
| **Origin** | <who asked, when, in their words> |

---

## 1. The problem

<What is wrong today, stated as evidence rather than assertion. A measurement, a reproduction,
a quoted complaint. If you cannot state the problem without hedging, the plan is premature.>

## 2. Decisions taken

| # | Decision |
|---|---|
| D1 | <settled, with the reasoning that settled it> |

<Open decisions go here too, marked as open, with a recommendation. A plan that hides an
unresolved question behind confident prose costs more than one that names it.>

## 3. Approach

<How it will be built. Enough that someone else could execute it.>

## 4. What could go wrong

| Risk | Mitigation |
|---|---|
| <the failure mode> | <what makes it detectable or reversible> |

## 5. Acceptance criteria

1. <Checkable. "Works correctly" is not a criterion; "`--check` exits 0" is.>

---

## Implementation notes

<!--
  Added AFTER work starts. The plan above is frozen (SPEC 2.2) - do not rewrite it to match
  what actually happened. Deviations, discovered constraints and corrections go here, dated.
  This footer is what makes a retrospective possible.
-->
