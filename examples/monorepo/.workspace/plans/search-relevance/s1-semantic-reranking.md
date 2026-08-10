---
type: plan
status: paused
updated: 2026-08-10
epic: search-relevance
scope: [packages/search-core]
---

# S1 - semantic reranking

| | |
|---|---|
| **Created** | 2026-08-08 |
| **Status** | Paused. A spike exists on `spike/reranking` and is not merged. Paused rather than blocked: the decision is ours to make, nobody else is holding it. |
| **Scope** | packages/search-core |
| **Origin** | Search relevance epic, 2026-08-01 |

---

<!-- `paused` rather than `blocked` is the distinction SPEC 5 cares about most. Blocked means
     someone else has to act; paused means we chose to stop and can choose to restart. Marking
     this `blocked` would suggest an external dependency that does not exist. -->

## 1. The problem

Lexical search ranks by term overlap, so "waterproof jacket" does not match "rain coat" at all.
Measured on the top 500 queries of July, 18% returned nothing relevant in the first five results
despite relevant stock existing.

## 2. Decisions taken

| # | Decision |
|---|---|
| D1 | Rerank the top 100 lexical results rather than replacing retrieval; a full vector index is a much larger change with a worse failure mode |
| D2 | **Open:** buy embeddings from a provider, or run a model ourselves. Recommendation: buy for the first release, on the grounds that we do not yet know the query mix well enough to size our own. |

## 3. Approach

Retrieve 100 lexically, embed the query, rerank by cosine similarity, return 20. Falls back to
pure lexical ordering if the embedding step fails, so search never goes down because reranking
does.

## 4. What could go wrong

| Risk | Mitigation |
|---|---|
| Added latency on every search | Rerank only when the lexical top result scores below a threshold |
| Provider outage takes search down | Fallback path returns lexical order; the spike proves it works |

## 5. Acceptance criteria

1. The 18% figure above drops below 5% on the same query set
2. p95 search latency rises by no more than 40ms
3. Killing the embedding service leaves search working, with lexical ordering
