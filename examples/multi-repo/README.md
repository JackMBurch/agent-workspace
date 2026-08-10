# Example: multi-repo layout

A fictional e-commerce project. The project root is **not** a git repository; the code lives in
sibling repositories, and the workspace is another repository beside them.

```
storefront-project/
  payments-api/      (git repo)
  storefront/        (git repo)
  .workspace/        (git repo)  <- this example
```

Because there is no enclosing repository, **no ignore configuration is needed**. Compare with
[`../monorepo/`](../monorepo/), where there is.

## What this example demonstrates

| File | Shows |
|---|---|
| `trackers/checkout-v2.md` | An epic tracker: item table, open questions, dated log. The one file allowed to churn. |
| `plans/checkout-v2/c0-payment-intents.md` | A plan in `review`, with an *Implementation notes* footer recording two deviations rather than editing the plan to match |
| `plans/checkout-v2/c1-refunds.md` | `status: blocked` with a `blocked-on:` naming what is waited on and since when |
| `plans/archive/legacy-cart-rewrite.md` | `abandoned`, kept deliberately as a warning with the original text unedited |
| `sessions/2026-08-09-payment-intents-push.md` | A parked session: exact next step, per-repo state, verified separated from assumed |
| `docs/how-checkout-works.md` | A `done` doc outside `archive/` - the SPEC 5.2 exemption |
| `docs/investigations/gateway-latency.md` | A closed investigation, explicitly not a work item |

## Try it

The example ships content and `config.toml` but no `bin/`, because the tooling is copied in by
bootstrap rather than duplicated per example. To run the validator against it:

```
cp -r examples/multi-repo /tmp/example
mkdir -p /tmp/example/.workspace/bin
cp lib/build-index.py /tmp/example/.workspace/bin/
python3 /tmp/example/.workspace/bin/build-index.py --check
```

It should report no problems. Now break it the way real workspaces break - make the tracker older
than one of its plans:

```
sed -i 's/^updated: 2026-08-10/updated: 2026-08-01/' /tmp/example/.workspace/trackers/checkout-v2.md
python3 /tmp/example/.workspace/bin/build-index.py --check
```

That is failure F2 from the spec, caught mechanically.

## A note on `stale_days`

This example sets `stale_days = 36500`. A committed example has frozen dates and would otherwise
fail the staleness check for anyone cloning it later. **Do not copy that setting into a real
workspace** - 21 days is the point of the check.
