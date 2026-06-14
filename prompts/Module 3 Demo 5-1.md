Use the prompt below with your GenAI tool to practice **alert triage**, understanding what a firing alert means, likely causes, and what to check first. This scenario uses a single `KubePodCrashLooping` alert on the payment API in EKS.

---

## AI prompt (copy into your assistant)

```text
I received this Prometheus alert on our EKS cluster:

  Alert: KubePodCrashLooping
  Pod: payment-api-7d9f8b-xkp2q
  Namespace: payments
  Message: Pod has been restarting 5 times in the last 15 minutes

We are running a Node.js payment API deployed with Kubernetes.
What does this alert mean, what is likely causing it, and what
should I check first?
```

---

## Alert details

| Field | Value |
|-------|--------|
| Alert name | `KubePodCrashLooping` |
| Pod | `payment-api-7d9f8b-xkp2q` |
| Namespace | `payments` |
| Message | Pod has been restarting 5 times in the last 15 minutes |

---

## Environment context

| Item | Value |
|------|--------|
| Workload | Node.js payment API |
| Platform | AWS EKS |
| Observability | Prometheus (kube-prometheus-stack) |

---

## What a good response should cover

| Area | Detail |
|------|--------|
| **Alert meaning** | What `KubePodCrashLooping` indicates about pod lifecycle and restart behavior |
| **Likely causes** | Application crash, failed health checks, OOM, misconfiguration, missing secrets, image pull failures |
| **First checks** | `kubectl describe pod`, `kubectl logs` (current and previous), events, resource limits, probe configuration |

---

## Quick checklist for reviewers

- [ ] Explains crash loop vs. a single restart
- [ ] Suggests checking **previous** container logs (`--previous`)
- [ ] Mentions pod events and exit codes
- [ ] Recommends concrete `kubectl` commands scoped to the pod and namespace
