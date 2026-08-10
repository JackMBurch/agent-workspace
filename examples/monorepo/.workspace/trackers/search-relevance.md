---
type: tracker
status: active
updated: 2026-08-10
epic: search-relevance
scope: [packages/search-core, apps/web]
---

# Search relevance

| | |
|---|---|
| **Updated** | 2026-08-10 |
| **State** | S0 shipped. S1 is paused pending a decision on whether to buy or build the embedding step. |
| **Next** | Decide buy vs build on embeddings. Everything in S1 hangs off it. |

<!-- `scope` names packages rather than repositories. That is the only difference the monorepo
     layout makes to a file: the structure, schema and rules are all identical. -->

## Items

| # | Item | Status | Notes |
|---|---|---|---|
| S0 | Typo tolerance | done | Shipped 2026-08-08 |
| S1 | Semantic reranking | paused | Blocked on a buy-vs-build decision, not on a person |
| S2 | Per-locale stopwords | open | Needs S0 only |

## Open questions

| Question | Asked | Waiting on | Blocks |
|---|---|---|---|
| Buy embeddings or run our own? | 2026-08-08 | Engineering leadership | S1 |

## Plans under this epic

- [`s1-semantic-reranking.md`](../plans/search-relevance/s1-semantic-reranking.md) - paused

## Log

- **2026-08-10** - S1 paused pending the buy-vs-build decision.
- **2026-08-08** - S0 shipped. Typo tolerance live for all locales.
