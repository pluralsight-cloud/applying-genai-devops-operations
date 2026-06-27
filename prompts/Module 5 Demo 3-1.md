# Module 5 — Demo 3 (Part 1): Traffic and capacity analysis from Prometheus metrics

Use the prompt below with your GenAI tool to turn collected Prometheus metrics into a **structured traffic and capacity analysis**, ending with a machine-readable capacity model used as input to Part 2.

---

## Role

You are a senior SRE and capacity engineer analyzing Prometheus metrics for the Globalmatics payment API running on AWS EKS.

---

## Environment

- **Payment API:** Node.js / Express, namespace: `payment-api`
- **EKS cluster:** Terraform-managed, `us-east-1`
- **Metrics:** collected via Prometheus (kube-prometheus-stack)
- **CPU limit per pod:** read from `metrics/cpu-limit-per-pod.json`
- **Current HPA and deployment state:** `metrics/hpa-current.json` and `metrics/deployment-current.json`

---

## Metrics files

Read all files before producing any output.

| File | Contents |
|------|----------|
| `metrics/manifest.json` | Collection timestamp and resolution. Use this to anchor all time references in your analysis. |
| `metrics/rps-7d-1h.json` | Requests per second — 7 days at 1h resolution. Primary source for traffic pattern identification. |
| `metrics/rps-30d-1h.json` | Requests per second — 30 days at 1h resolution. Used to identify longer-term growth trend. |
| `metrics/cpu-cores-7d-1h.json` | Absolute CPU cores consumed — 7 days at 1h resolution. Used alongside RPS to derive the CPU/RPS relationship. |
| `metrics/cpu-pct-of-limit-7d-1h.json` | CPU utilisation as a percentage of the configured limit. Used to determine how close to saturation the pods run. |
| `metrics/replicas-7d-1h.json` | Available replica count over 7 days. Used to normalise per-pod metrics. |
| `metrics/p99-latency-7d-1h.json` | P99 response latency over 7 days. Used to identify whether latency degrades at high RPS. |
| `metrics/peak-rps-7d.json` | Single highest RPS value observed in the last 7 days. |
| `metrics/trough-rps-7d.json` | Single lowest non-zero RPS value in the last 7 days. |
| `metrics/cpu-limit-per-pod.json` | CPU limit configured per pod (in cores). |
| `metrics/hpa-current.json` | Current HPA configuration if one exists. |
| `metrics/deployment-current.json` | Current deployment spec including replica count and resource requests/limits. |

---

## Task

Produce a structured traffic and capacity analysis report.

### 1. Traffic pattern analysis

Using `rps-7d-1h.json` and `rps-30d-1h.json`:

**Daily pattern**

- Identify the peak hour and trough hour of an average day
- State average RPS during business hours vs off-peak hours
- Calculate the peak-to-trough ratio

**Weekly pattern**

- Identify which days of the week carry the highest traffic
- Identify which days carry the lowest traffic
- State whether the pattern is consistent week-over-week

**Traffic characterisation**

- Baseline RPS: the sustained floor during normal operation
- Average RPS: mean across the full 7-day window
- Peak RPS: from `peak-rps-7d.json`
- Trough RPS: from `trough-rps-7d.json`
- Burst factor: peak RPS / average RPS

**Growth signal** (from `rps-30d-1h.json`)

- Compare week 1 average vs week 4 average RPS
- Calculate implied week-over-week growth rate
- State whether growth appears linear, exponential, or flat

### 2. CPU/RPS capacity model

Using `cpu-cores-7d-1h.json`, `cpu-pct-of-limit-7d-1h.json`, `replicas-7d-1h.json`, and `cpu-limit-per-pod.json`:

**Per-pod normalisation**

At each hourly data point: divide total CPU by replica count to get per-pod CPU consumption. Pair each point with the corresponding RPS value from `rps-7d-1h.json`.

**Linear capacity model**

Fit a linear relationship:

```text
CPU_per_pod (millicores) = A × RPS_per_pod + B
```

where:

- `RPS_per_pod` = total RPS / replica count at that timestamp
- `A` = marginal CPU cost per additional request/second
- `B` = idle baseline CPU (non-traffic overhead)

State:

- The value of `A` (millicores per RPS)
- The value of `B` (baseline idle millicores)
- R² goodness of fit — how linear is the relationship?
- Any data points that deviate significantly (latency spikes, cold start events) and how they were handled

**Saturation analysis**

Using `cpu-pct-of-limit-7d-1h.json`:

- At what RPS per pod does CPU% of limit exceed 70%?
- At what RPS per pod does CPU% of limit exceed 85%?
- Has the deployment ever approached saturation in the last 7 days? If so: timestamp, RPS value, and CPU% observed.

**Capacity table**

Generate a table showing safe RPS capacity at various replica counts:

| Replicas | Safe RPS (70% CPU target) | Max RPS (85% CPU) | CPU limit headroom |
|----------|---------------------------|-------------------|--------------------|

Calculate from: `safe_RPS = replicas × ((target_cpu_pct × cpu_limit_per_pod) - B) / A`. Cover replicas 2 through 12.

### 3. Latency correlation

Using `p99-latency-7d-1h.json` and `rps-7d-1h.json`:

- Does P99 latency increase as RPS increases?
- Identify the RPS threshold above which P99 latency exceeds 500ms
- Note whether this latency threshold is more restrictive than the CPU-based capacity model above

### 4. Current state assessment

Using `hpa-current.json` and `deployment-current.json`:

- State the current `minReplicas`, `maxReplicas`, and CPU target
- Compare current `maxReplicas` against the capacity table above
- Is the current HPA configuration adequate for observed peak traffic?
- What is the gap, if any, between current max capacity and observed peak demand?

### 5. Capacity model summary (machine-readable — used as input to Part 2)

Output this section as a JSON block for use in the next prompt:

```json
{
  "model": {
    "cpu_per_rps_millicores": "[A value]",
    "baseline_cpu_millicores": "[B value]",
    "cpu_limit_per_pod_millicores": "[from cpu-limit-per-pod.json]",
    "r_squared": "[goodness of fit]"
  },
  "traffic": {
    "peak_rps_observed": "[from peak-rps-7d.json]",
    "average_rps_7d": "[computed]",
    "trough_rps": "[from trough-rps-7d.json]",
    "burst_factor": "[peak/average]",
    "peak_hour_utc": "[hour 0-23]",
    "peak_day_of_week": "[0=Sunday]",
    "weekly_growth_rate_pct": "[implied from 30d data]"
  },
  "current_config": {
    "min_replicas": "[from hpa-current.json]",
    "max_replicas": "[from hpa-current.json]",
    "cpu_target_pct": "[from hpa-current.json]",
    "latency_saturation_rps_per_pod": "[from latency analysis]"
  }
}
```

---

## Output rules

- Use `[INSUFFICIENT DATA]` where a file does not contain enough data points to compute a reliable value.
- Anchor every observation to specific timestamps from the data.
