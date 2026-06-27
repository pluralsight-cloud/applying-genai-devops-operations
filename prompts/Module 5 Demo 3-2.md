# Module 5 — Demo 3 (Part 2): Traffic growth forecast and replica plan

Use the prompt below with your GenAI tool to turn the capacity model from Part 1 plus a set of growth assumptions into a **traffic forecast and replica requirement plan**, ending with a machine-readable forecast summary.

---

## Role

You are a capacity planning engineer generating a traffic growth forecast for the Globalmatics payment API on AWS EKS.

---

## Inputs

**Capacity model**:
Use the capacity-analysis.md file in the metrics directory.

**Growth assumptions** — provide these values before running the prompt:

| Assumption | Example value |
|------------|---------------|
| Organic monthly growth rate | `15%` |
| Planned product launch | date and expected traffic multiplier, or `none` |
| Seasonal peak event | `Black Friday — 3× average, last Friday of November`, or `none` |
| Safety headroom margin | `25%` — replicas above forecast to absorb unexpected spikes |
| Forecast horizon | 30 days / 60 days / 90 days |

---

## Task

Using the capacity model and growth assumptions, produce a structured traffic forecast and replica requirement plan.

### 1. Baseline projection

Starting from the current average RPS in the capacity model, apply the monthly growth rate to project traffic forward.

For each 30-day period:

- Projected average RPS
- Projected peak RPS (apply `burst_factor` from model)
- Projected trough RPS

Show the compound effect: if week-over-week growth from the 30-day Prometheus data differs from the stated monthly rate, flag the discrepancy and use the observed rate as the primary signal with the stated rate as a secondary check.

### 2. Replica requirement forecast

Using the capacity model formula:

```text
required_replicas = ceil(
  (peak_RPS × cpu_per_rps_millicores + baseline_cpu_millicores)
  / (cpu_target_pct × cpu_limit_per_pod_millicores)
) × (1 + safety_headroom_margin)
```

Apply this formula to the projected peak RPS at each period. Round up to the nearest whole number.

**Forecast table**

| Period | Avg RPS | Peak RPS | Min Replicas | Max Replicas | CPU target % |
|--------|---------|----------|--------------|--------------|--------------|

- Rows: current state, 30 days, 60 days, 90 days
- Min replicas: sufficient for trough RPS at 50% CPU
- Max replicas: sufficient for peak RPS + safety headroom at target CPU

### 3. Seasonal and event adjustments

If a planned launch or seasonal peak was provided:

- State the date range of the elevated period
- Calculate peak RPS during the event (`event_multiplier × projected_average_RPS_at_that_date`)
- Calculate required replicas during the event
- Recommend a temporary `maxReplicas` override for the event window
- Recommend when to pre-scale (how many hours before peak) based on the HPA scale-up behavior

### 4. Latency constraint check

Using `latency_saturation_rps_per_pod` from the capacity model: if the forecast peak RPS per pod (`peak_RPS / max_replicas`) approaches the latency saturation threshold:

- Flag this as a latency risk
- Recalculate `max_replicas` using the latency threshold instead of the CPU threshold
- Use whichever constraint requires MORE replicas

### 5. Cost projection

Estimate the infrastructure cost impact of the forecast:

- Current monthly cost: `current_replicas × [NODE_COST_PER_REPLICA]`
- 30-day forecast cost: `forecast_max_replicas_30d × node cost`
- 90-day forecast cost: `forecast_max_replicas_90d × node cost`

`NODE_COST_PER_REPLICA`: `[paste your EC2 instance hourly rate × 730]` or use `[COST_UNKNOWN]` if not available.

### 6. Forecast summary (machine-readable — used as input to Prompt 3)

Output this section as a JSON block:

```json
{
  "forecast": {
    "current": {
      "avg_rps": "[value]",
      "peak_rps": "[value]",
      "min_replicas": "[value]",
      "max_replicas": "[value]"
    },
    "day_30": {
      "avg_rps": "[value]",
      "peak_rps": "[value]",
      "min_replicas": "[value]",
      "max_replicas": "[value]"
    },
    "day_60": {
      "avg_rps": "[value]",
      "peak_rps": "[value]",
      "min_replicas": "[value]",
      "max_replicas": "[value]"
    },
    "day_90": {
      "avg_rps": "[value]",
      "peak_rps": "[value]",
      "min_replicas": "[value]",
      "max_replicas": "[value]"
    },
    "seasonal_event": {
      "date": "[date or null]",
      "peak_rps": "[value or null]",
      "required_replicas": "[value or null]",
      "pre_scale_hours_before": "[value or null]"
    }
  },
  "hpa_targets": {
    "min_replicas": "[day_90 min — most conservative]",
    "max_replicas": "[day_90 max + seasonal if applicable]",
    "target_cpu_pct": "[from capacity model]",
    "scale_up_trigger_rps": "[RPS at which next replica is needed]",
    "latency_constrained": "[true/false]"
  }
}
```

Save the forcast summary to traffic-forecast.md in the metrics directory.
