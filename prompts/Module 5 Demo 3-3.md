You are a senior platform engineer generating a production-ready
Kubernetes HPA manifest for the Globalmatics payment API.

INPUTS
------
FORECAST SUMMARY:
Use traffic-forecast.md in the metrics directory.

DEPLOYMENT CONTEXT
------------------
- Deployment name:    payment-api
- Namespace:          payment-api
- Container name:     payment-api
- CPU limit per pod:  [read from metrics/cpu-limit-per-pod.json]
- Current HPA:        [read from metrics/hpa-current.json — note
                       any existing policies being replaced]

PAYMENT API BEHAVIOR CONSTRAINTS
---------------------------------
These constraints must be reflected in the behavior policies:

Scale-up must be AGGRESSIVE:
  Payment traffic spikes are sudden — a viral event or batch
  settlement window can double RPS in under 60 seconds.
  The HPA must add capacity faster than it normally would
  to prevent latency degradation or request queuing.

Scale-down must be CONSERVATIVE:
  Scaling down too quickly after a spike causes thrashing —
  the HPA removes pods, traffic rebounds, pods must be added
  again. For a payment API, each pod restart risks in-flight
  transaction loss. Scale-down should be gradual and
  only after sustained low load.

Stabilisation windows must reflect traffic rhythm:
  The peak hour identified in Prompt 1 recurs daily.
  The scale-down stabilisation window must be long enough
  that the HPA does not scale down between the morning
  trough and the midday peak on the same day.

TASK
----
Generate a complete, production-ready HPA manifest and
supporting documentation.

1. HPA MANIFEST
   Generate a Kubernetes HorizontalPodAutoscaler manifest
   using autoscaling/v2 (required for behavior policies).

   CORE SETTINGS (derive from hpa_targets in forecast JSON):
   - minReplicas: hpa_targets.min_replicas
   - maxReplicas: hpa_targets.max_replicas
   - metrics: CPU utilisation targeting hpa_targets.target_cpu_pct

   SCALE-UP BEHAVIOR POLICY
   Configure an aggressive scale-up policy:
   - stabilizationWindowSeconds: 0
     (scale up immediately — no delay when CPU is high)
   - policies:
       * Pods policy: add up to 4 pods per 15 seconds
         (handles sudden spikes faster than the default 4/min)
       * Percent policy: add up to 100% of current replicas
         per 60 seconds (doubles capacity in one minute if needed)
   - selectPolicy: Max
     (use whichever policy adds MORE pods)

   SCALE-DOWN BEHAVIOR POLICY
   Configure a conservative scale-down policy:
   - stabilizationWindowSeconds: 1800
     (30-minute window — prevents scaling down into a recurring peak.
      Set to 3600 if peak_hour recurs within 2 hours of trough)
   - policies:
       * Pods policy: remove at most 1 pod per 5 minutes
       * Percent policy: remove at most 10% of replicas per 10 minutes
   - selectPolicy: Min
     (use whichever policy removes FEWER pods)

2. SEASONAL EVENT OVERRIDE (if seasonal_event in forecast is not null)
   Generate a second HPA manifest variant named
   hpa-seasonal-override.yaml with:
   - maxReplicas set to forecast.seasonal_event.required_replicas
   - Scale-up stabilizationWindowSeconds: 0
   - A comment block explaining when to apply and revert this override
   - The exact kubectl command to apply it:
     kubectl apply -f k8s/hpa-seasonal-override.yaml
   - The exact command to revert to the standard HPA:
     kubectl apply -f k8s/hpa.yaml

3. CONFIGMAP FOR CAPACITY MODEL REFERENCE
   Generate a Kubernetes ConfigMap named payment-api-capacity-model
   in namespace payment-api that stores the capacity model values
   from Prompt 1 as data fields. This makes the model auditable
   and accessible to other tooling:
   - cpu_per_rps_millicores
   - baseline_cpu_millicores
   - model_generated_at (timestamp from metrics/manifest.json)
   - peak_rps_observed
   - forecast_horizon_days
   - min_replicas
   - max_replicas

4. DIFF AGAINST CURRENT HPA
   Compare the generated manifest against metrics/hpa-current.json.
   For every field that changes:
   | Field | Current value | New value | Reason |
   If no current HPA exists, state this and note that the
   generated manifest is a new resource.

5. APPLY ORDER AND VERIFICATION
   a) The exact kubectl commands to apply in sequence:
      kubectl apply -f k8s/capacity-model-configmap.yaml
      kubectl apply -f k8s/hpa.yaml
      kubectl get hpa payment-api -n payment-api -w

   b) How to verify the HPA is working correctly after apply:
      - The kubectl command to watch HPA events in real time
      - The Prometheus query to confirm the HPA metric target
        is being read correctly:
        kube_horizontalpodautoscaler_status_current_replicas
        vs kube_horizontalpodautoscaler_spec_max_replicas
      - How to trigger a controlled scale-up test without
        sending real payment traffic

   c) Rollback: the exact command to restore the previous HPA
      if the new configuration causes issues.

OUTPUT FILES
------------
Produce three complete YAML files in this order:
  a) k8s/capacity-model-configmap.yaml
  b) k8s/hpa.yaml
  c) k8s/hpa-seasonal-override.yaml (or note if not applicable)

Include a comment block at the top of each file:
  # Generated: [timestamp]
  # Source: capacity model from metrics/ collected [manifest date]
  # Forecast horizon: 90 days
  # Review by: [DATE 90 days from now — add to team calendar]

Flag any value derived from [INSUFFICIENT DATA] in Prompt 1 or 2
with a YAML comment so the reviewer knows to validate it manually.