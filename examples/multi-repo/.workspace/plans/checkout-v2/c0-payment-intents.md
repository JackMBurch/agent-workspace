---
type: plan
status: review
updated: 2026-08-09
epic: checkout-v2
scope: [payments-api, storefront]
---

# C0 - payment intents endpoint

| | |
|---|---|
| **Created** | 2026-08-02 |
| **Status** | In review. `payments-api#412` and `storefront#88`, cross-linked. **#412 merges and deploys first** - #88 calls the endpoint it adds. |
| **Scope** | payments-api, storefront |
| **Origin** | Checkout v2 kickoff, 2026-08-01 |

---

## 1. The problem

The storefront charges cards directly at submit time. Two consequences, both measured on the
week of 2026-07-27:

- 3.1% of submissions fail on a network timeout after the charge has already been created,
  producing a charge with no order. 47 occurrences that week, all reconciled by hand.
- Any provider that requires a challenge step cannot be supported, because there is nowhere to
  park a half-completed payment.

## 2. Decisions taken

| # | Decision |
|---|---|
| D1 | Intent is created server-side before the client collects card details, so a timeout leaves an intent rather than a charge |
| D2 | Idempotency key is the cart id plus a monotonic attempt counter, so a client retry cannot double-charge |
| D3 | The old direct-charge path stays behind a flag for one release, for rollback |

## 3. Approach

`POST /payment-intents` on `payments-api` creates and returns an intent. The storefront confirms
against the provider client-side, then polls `GET /payment-intents/:id` until it settles. The
webhook remains the source of truth; the poll is only for user feedback.

## 4. What could go wrong

| Risk | Mitigation |
|---|---|
| Webhook and poll disagree | The webhook always wins; the poll never writes |
| Orphaned intents accumulate | A daily job expires anything unsettled after 24h |
| Flag left on after rollout | The flag is removed in C2, which is tracked as an item |

## 5. Acceptance criteria

1. A killed connection mid-submit leaves an intent and no charge
2. Replaying the same idempotency key returns the original intent, not a second one
3. Direct-charge path still works with the flag on

---

## Implementation notes

- **2026-08-09** - D2 needed amending during the build. The cart id alone was not unique enough
  because a cart survives a session, so two devices on the same cart collided. The attempt
  counter was added for that reason and is stored on the cart row, not in the client.
- **2026-08-09** - The 24h expiry job is not in this change. It is small but needs a scheduler
  that does not exist yet, so it moved to C2 rather than growing this PR.
