---
type: plan
status: blocked
updated: 2026-08-10
epic: checkout-v2
scope: [payments-api]
blocked-on: "a provider sandbox credential; requested 2026-08-06, chased 2026-08-10"
---

# C1 - refund flow

| | |
|---|---|
| **Created** | 2026-08-06 |
| **Status** | Blocked. The design is settled and the code is written up to the point where it needs a real sandbox to test against. |
| **Scope** | payments-api |
| **Origin** | Checkout v2 kickoff, 2026-08-01 |

---

## 1. The problem

Refunds are issued in the provider dashboard by hand. Nothing writes them back, so order state
and money disagree until someone notices. Support has raised it three times.

## 2. Decisions taken

| # | Decision |
|---|---|
| D1 | Partial refunds are supported from the start; retrofitting them means a schema change |
| D2 | A refund is a separate record, not a mutation of the payment, so history stays intact |

## 3. Approach

`POST /payments/:id/refunds` with an optional amount. Provider webhook confirms; the record is
`pending` until it does.

## 4. What could go wrong

| Risk | Mitigation |
|---|---|
| Over-refunding via concurrent requests | Amount checked against the sum of existing refunds inside a transaction |

## 5. Acceptance criteria

1. Two concurrent full refunds result in one refund and one rejection
2. A partial refund leaves the payment refundable for the remainder
3. Webhook replay does not create a duplicate record

---

## Implementation notes

- **2026-08-10** - Blocked. Criterion 1 cannot be demonstrated without a sandbox that accepts
  concurrent refunds, and the provider's test mode serialises them. Requested a real sandbox
  credential on 2026-08-06.
