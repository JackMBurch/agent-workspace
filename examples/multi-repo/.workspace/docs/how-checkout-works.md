---
type: doc
status: done
updated: 2026-08-03
scope: [payments-api, storefront]
---

# How checkout works

<!-- A `done` doc outside archive/, which SPEC 5.2 allows. Reference material is read rather
     than worked, and archiving it only makes it harder to find. -->

| | |
|---|---|
| **Written** | 2026-08-03 |
| **Question** | What happens between "place order" and money moving? |
| **Answer** | The storefront creates an intent server-side, confirms it with the provider client-side, and the provider webhook is the only thing that marks an order paid. |

---

## The path

1. Storefront posts the cart to `payments-api`, which creates a payment intent and returns its
   client secret.
2. The storefront confirms with the provider directly. Card details never reach our servers.
3. The provider calls our webhook. **This is the only write that marks an order paid.**
4. The storefront polls the intent for user feedback only. It never writes.

## Why the webhook is the only writer

A client can be closed, throttled, or lying. The webhook is the one report of payment state that
does not depend on the buyer's device still existing. Every attempt to shortcut this has ended
with orders marked paid that were not.

## What this does not cover

Refunds, which are C1 and not built yet. Subscriptions, which do not exist. The legacy
direct-charge path, which is still present behind a flag but is being removed.
