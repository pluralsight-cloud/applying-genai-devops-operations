Use the prompt below with your GenAI tool to practice **reading alert rules**, understanding what a PromQL expression measures, what the threshold means, and how to interpret a firing value.

---

## AI prompt (copy into your assistant)

```text
This alert is firing and I need to understand what it is actually
measuring before I respond to it:

  expr: |
    (
      sum(rate(http_requests_total{job="payment-api",status=~"5.."}[5m]))
      /
      sum(rate(http_requests_total{job="payment-api"}[5m]))
    ) > 0.05
  for: 2m

Explain what this expression is measuring in plain English,
what the 0.05 threshold means, and what a value of 0.12
at the time of firing tells me about the current state
of the payment API.
```

---

## Alert rule under review

```yaml
expr: |
  (
    sum(rate(http_requests_total{job="payment-api",status=~"5.."}[5m]))
    /
    sum(rate(http_requests_total{job="payment-api"}[5m]))
  ) > 0.05
for: 2m
```

---

## Expression breakdown

| Part | Meaning |
|------|---------|
| `http_requests_total{job="payment-api"}` | Counter of HTTP requests for the payment API scrape target |
| `status=~"5.."` | Regex match — HTTP **5xx** status codes only |
| `rate(...[5m])` | Per-second rate over the last **5 minutes** |
| Numerator | Rate of **5xx** responses |
| Denominator | Rate of **all** responses |
| `> 0.05` | Fires when the ratio exceeds **5%** |
| `for: 2m` | Condition must hold for **2 minutes** before alerting |

---

## Values to interpret

| Value | Meaning |
|-------|---------|
| **0.05** (threshold) | Alert fires when more than **5%** of requests return 5xx over the 5m window |
| **0.12** (at firing) | **12%** of requests are failing with 5xx — roughly **2.4×** the allowed error budget for this rule |

---

## What a good response should cover

| Area | Detail |
|------|--------|
| **Plain-English metric** | 5xx error **ratio** (not raw count) over a 5-minute rolling window |
| **Threshold semantics** | 5% failure rate sustained for 2 minutes |
| **Current state at 0.12** | Elevated server-side failures; customer-impacting degradation |
| **Caveats** | Low traffic can make ratios noisy; `sum()` aggregates all routes/methods |

---

## Quick checklist for reviewers

- [ ] Describes the metric as a **ratio / percentage**, not an absolute request count
- [ ] Explains **`for: 2m`** prevents flapping on brief spikes
- [ ] Interprets **0.12** as 12% 5xx rate (above the 5% threshold)
- [ ] Notes that `status=~"5.."` matches 500–599, not 4xx client errors
