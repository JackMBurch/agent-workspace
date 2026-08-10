---
type: plan
status: abandoned
updated: 2026-07-28
epic: checkout-v2
scope: [storefront]
superseded-by: plans/checkout-v2/c0-payment-intents.md
---

# Legacy cart rewrite - ABANDONED

| | |
|---|---|
| **Created** | 2026-06-30 |
| **Status** | **ABANDONED 2026-07-28. Do not revive this.** Roughly 2,000 lines were written and committed on `feat/cart-rewrite` before it was stopped. That branch still exists and still builds. |
| **Origin** | Pre-dates the checkout-v2 epic |

---

> **Read this box before anything else in this file.**
>
> This plan is kept because it is a trap, not because it is useful. It is detailed, it is
> confident, and it has real working code behind it, which together make it look like a head
> start. It is not one.
>
> **Why it was abandoned:** it rebuilt the cart around a client-side state machine, which makes
> the payment-intent model in C0 impossible - an intent has to be created server-side before the
> client does anything, and this design has no server-side step at that point. The two cannot be
> reconciled by patching; C0 replaced the approach entirely.
>
> If you are here because you found `feat/cart-rewrite` and wondered what it was: that is what
> it was. Do not cherry-pick from it.

## Original plan

<!-- Kept verbatim and unedited. Rewriting an abandoned plan to explain itself better would
     destroy the evidence of what was actually believed at the time, which is the only thing
     that makes the warning above credible. -->

Move cart state into a client-side reducer, persist to local storage, and reconcile with the
server only at submit. Removes four round trips and makes the cart work offline.

...
