---
type: session
status: paused
updated: 2026-08-09
epic: checkout-v2
scope: [payments-api, storefront]
---

# C0 pushed, PRs open - 2026-08-09

| | |
|---|---|
| **Stopped because** | End of the day; C0 is at a natural boundary |
| **Resumable** | Yes, cleanly. Nothing uncommitted. |

## The exact next step

Chase the provider sandbox credential (requested 2026-08-06) so C1's concurrency criterion can
be tested. Everything else on C1 is written and waiting on that one thing.

## State per repo

| Repo | Branch | Base | Uncommitted | Unpushed | PR |
|---|---|---|---|---|---|
| payments-api | `feat/payment-intents` | `main` | none | 0 | #412, open, review requested |
| storefront | `feat/payment-intents` | `main` | none | 0 | #88, open, review requested |

## Verified vs assumed

- **Verified:** both PRs open and cross-linked (checked in the UI). Criteria 1 and 2 demonstrated
  locally against the provider test mode - killed the connection with the network panel, saw an
  intent and no charge. Full test suite green on both branches.
- **Assumed:** that #412 deploys before #88 is merged. Nothing enforces the ordering; it is a
  note in both PR bodies and a line in the tracker. If #88 lands first the storefront calls an
  endpoint that does not exist yet.

## What would trip up a fresh session

- The flag from D3 defaults to **on** in staging and **off** in production. Testing the new path
  on staging without flipping it exercises the old code and looks like the change did nothing.
- `feat/cart-rewrite` still exists and still builds. It is abandoned - see
  `plans/archive/legacy-cart-rewrite.md` before touching it.
