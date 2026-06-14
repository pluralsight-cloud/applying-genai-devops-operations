Use the prompt below with your GenAI tool to practice **incident correlation**, when several alerts fire at once, determine which signal is the root cause and which are downstream effects.

---

## AI prompt (copy into your assistant)

```text
The following alerts fired within 2 minutes of each other on our
EKS cluster running a payment API:

  1. PaymentAPIHighErrorRate — 5xx rate at 34%
  2. PaymentAPICriticalLatency — P99 at 2,400ms
  3. KubePodCrashLooping — payment-api pods restarting
  4. KubeNodeNotReady — one node in NotReady state

Which of these is most likely the root cause and which are
downstream effects? What should I investigate first?
```

---

## Alerts fired (within 2 minutes)

| # | Alert | Signal |
|---|-------|--------|
| 1 | `PaymentAPIHighErrorRate` | 5xx rate at **34%** |
| 2 | `PaymentAPICriticalLatency` | P99 at **2,400 ms** |
| 3 | `KubePodCrashLooping` | `payment-api` pods restarting |
| 4 | `KubeNodeNotReady` | One node in **NotReady** state |

---

## Environment context

| Item | Value |
|------|--------|
| Workload | Node.js payment API |
| Platform | AWS EKS |
| Observability | Prometheus + Alertmanager |

---

## What a good response should cover

| Area | Detail |
|------|--------|
| **Root cause ranking** | Most likely primary failure (often infrastructure before application symptoms) |
| **Downstream effects** | How node failure can cause pod restarts, elevated latency, and error rates |
| **Investigation order** | Node health → pod scheduling/eviction → application logs and upstream dependencies |
| **First commands** | `kubectl get nodes`, `kubectl describe node`, pod distribution, events |

---

## Quick checklist for reviewers

- [ ] Identifies **`KubeNodeNotReady`** as a plausible root cause (not just the app alerts)
- [ ] Explains why error rate and latency alerts may be **symptoms**, not the origin
- [ ] Connects pod crash looping to node pressure or eviction
- [ ] Recommends checking node conditions, capacity, and pod rescheduling before diving into app code
