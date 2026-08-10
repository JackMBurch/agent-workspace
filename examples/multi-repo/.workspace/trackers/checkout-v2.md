---
type: tracker
status: active
updated: 2026-08-10
epic: checkout-v2
scope: [payments-api, storefront]
---

# Checkout v2

| | |
|---|---|
| **Updated** | 2026-08-10 |
| **State** | C0 is in review and merges first (it adds the endpoint C1 calls). C1 is blocked on a sandbox credential. |
| **Next** | Chase the sandbox credential; it is the only thing holding C1. |

## Items

| # | Item | Status | Notes |
|---|---|---|---|
| C0 | Payment intents endpoint | review | `payments-api#412`, `storefront#88`. **#412 merges first.** |
| C1 | Refund flow | blocked | Needs a provider sandbox credential |
| C2 | Guest checkout | open | Not started; no dependency on C0 or C1 |
| C3 | Saved cards | dropped | Superseded by the provider's own vault. See the log. |

## Open questions

| Question | Asked | Waiting on | Blocks |
|---|---|---|---|
| Do we keep supporting the legacy cart cookie after cutover? | 2026-08-04 | Product | C2 |

## Plans under this epic

- [`c0-payment-intents.md`](../plans/checkout-v2/c0-payment-intents.md) - the endpoint and its client
- [`c1-refunds.md`](../plans/checkout-v2/c1-refunds.md) - blocked on a credential

## Log

- **2026-08-10** - C1 blocked: the provider sandbox credential has not arrived.
- **2026-08-09** - C0 pushed, both PRs open and cross-linked.
- **2026-08-05** - C3 dropped. The provider shipped a vault that does what C3 planned to build,
  so building it would have been duplicated effort with a worse security story.
- **2026-08-01** - Epic opened.
