---
type: doc
status: done
updated: 2026-07-22
scope: [payments-api]
---

# Investigation: gateway latency spikes

| | |
|---|---|
| **Written** | 2026-07-22 |
| **Question** | Why does `payments-api` p99 jump to 4s for a few minutes each hour? |
| **Answer** | Not the gateway. A cron job on the same host rebuilds a materialised view and saturates disk IO. |

---

## Findings

The spikes correlate exactly with `:07` past each hour, which is the schedule of the reporting
view rebuild, not anything in the request path. Gateway response times measured at the provider's
edge are flat throughout. The latency is entirely local queueing.

Moving the rebuild to the read replica removed the spikes in staging. Not yet done in production.

**This is a closed investigation, not a work item.** The fix it implies is tracked separately.

## Method

- Provider edge timings pulled for the same window and compared against ours
- `iostat` sampled at one-second resolution across two spike windows
- Rebuild disabled for one hour as a control; no spike occurred

## What this does not cover

Whether the read replica can absorb the rebuild under peak load. It was tested at 3am traffic
levels only, which is not a fair test.
