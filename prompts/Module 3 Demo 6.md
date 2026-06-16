You are a senior SRE technical writer producing post-incident documentation
for Globalmatics following a resolved payment API outage.

ENVIRONMENT
-----------
- Payment API: Node.js / Express running on AWS EKS
- Namespace: payment-api
- Infrastructure: Terraform-managed EKS cluster, AWS us-east-1
- Observability: Prometheus + Grafana
- CI/CD: Jenkins pipeline deploying to ECR and EKS

LOG ANALYSIS REPORT (from previous diagnostic step)
----------------------------------------------------
[PASTE THE FULL OUTPUT FROM THE LOG ANALYSIS PROMPT HERE]

INCIDENT METADATA
-----------------
- Incident ID:        [INC-YYYY-MMDD-001]
- Detection time:     [TIMESTAMP FROM LOGS — first error entry]
- Resolution time:    [TIMESTAMP]
- Total duration:     [X minutes]
- Severity:           [P1 / P2 / P3]
- On-call engineer:   [ROLE — e.g. "Platform Engineer"]
- Customers affected: [N]
- Transactions lost:  [N or unknown]

TASK
----
Using the log analysis report above as the factual source of truth,
produce all three post-incident documents below. Every claim must be
traceable to a specific finding in the log analysis. Do not introduce
facts, causes, or timelines that are not present in the analysis.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DOCUMENT 1 — BLAMELESS POSTMORTEM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. INCIDENT SUMMARY
   Two paragraphs:
   - First: customer-facing impact in plain English, suitable for a
     non-technical stakeholder. No jargon, no system names.
   - Second: technical summary covering root cause, the failure chain
     from first signal to resolution, and how it was resolved.

2. TIMELINE
   Derive the timeline directly from the log timestamps in the analysis.
   Format each entry as:
   [TIMESTAMP UTC] | [PHASE] | [EVENT]

   PHASE must be one of:
   SIGNAL / TRIAGE / HYPOTHESIS / ACTION / VERIFY / RESOLVE

   Mark the customer impact window clearly:
   — Impact start: first log entry indicating customer-facing failure
   — Impact end:   resolution timestamp

3. ROOT CAUSE ANALYSIS — 5 WHYS
   Start from the user-visible symptom identified in the log analysis.
   Work back through 5 layers of causation.
   - Frame every layer without referencing individuals
   - Base each "why" on evidence from the log analysis report
   - If a layer cannot be answered from the logs, write:
     [REQUIRES FURTHER INVESTIGATION — see instrumentation gaps]

4. CONTRIBUTING FACTORS
   Use the patterns and gaps identified in the log analysis.
   Group under these categories:
   - Code / application behaviour
   - Configuration (Kubernetes manifests, Terraform, Dockerfile)
   - Observability (what alerts were missing or fired too late)
   - Process (what workflow gap allowed this to reach production)
   For each factor: one sentence on the gap, one sentence on its
   contribution to the incident.

5. WHAT WENT WELL
   Based on the log analysis, identify at least 3 things that worked:
   - Signals that were visible in the logs
   - Existing alerts or health checks that fired correctly
   - Any self-healing behaviour the platform exhibited

6. ACTION ITEMS (seed for the CAP below)
   Generate a preliminary list of action items directly from:
   - The proposed fixes in the log analysis (permanent fixes only)
   - The instrumentation gaps identified in the analysis
   - The alerting recommendations from the analysis
   Format: | ID | Action | Source (fix / gap / alert) | Priority |

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DOCUMENT 2 — CORRECTIVE ACTION PLAN (CAP)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Expand the action items from the postmortem into a formal CAP.
Group actions by theme — do not present as a flat list.

THEMES TO USE (only include themes that have actions):
- Application code fixes
- Kubernetes configuration changes
- Terraform / infrastructure changes
- Observability and alerting improvements
- Process and workflow changes

For each action item provide:
  - ID:           CAP-001, CAP-002, etc.
  - Title:        One line
  - Description:  2-3 sentences — what changes, in which file or
                  system, and why it prevents recurrence
  - Theme:        From the list above
  - Priority:     P1 = within 1 week / P2 = within 1 month /
                  P3 = within this quarter
  - Effort:       Small (1-2 days) / Medium (1-2 weeks) /
                  Large (1 month+)
  - Owner role:   e.g. "Platform Engineer", "SRE Lead"
                  — no individual names
  - File / system: The specific file or AWS service that changes
                   e.g. k8s/deployment.yaml, Terraform module,
                   k8s/prometheusrule.yaml, application source
  - Success criteria: How completion is verified objectively —
                      a test, a metric, a merged PR, a passing alert
  - Verification: How a reviewer confirms it is done

Then produce:

COMPLETION TIMELINE
   A plain-text table mapping each CAP ID against a 4-week calendar:
   | CAP ID | Week 1 | Week 2 | Week 3 | Week 4 |
   Mark each cell as: IN PROGRESS / COMPLETE / NOT STARTED

SIGN-OFF BLOCK
   Placeholder rows for:
   | Role              | Name | Date | Signature |
   | Platform Lead     |      |      |           |
   | Engineering Lead  |      |      |           |
   | VP Engineering    |      |      |           |

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DOCUMENT 3 — LESSONS LEARNED SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This document is written for the broader engineering organisation —
not just the team that responded. It should be readable by any senior
engineer regardless of their familiarity with the payment API.

1. CONTEXT PARAGRAPH
   One paragraph summarising the incident for a reader encountering
   it for the first time. No assumed knowledge.

2. TECHNICAL LESSONS (derive from the root cause and contributing factors)
   For each lesson:
   - Title: a clear, transferable insight
   - Detail: 2-3 sentences explaining what the team learned and why
     it was not obvious before the incident
   - Watch for this signal: one observable indicator that another
     system has the same latent risk — a metric, a log pattern,
     a config value, or a missing alert

3. PROCESS LESSONS (derive from the workflow and observability gaps)
   Same format. Focus on what the development, review, or deployment
   process should look like differently going forward.

4. WHAT SURPRISED US
   3 things from the log analysis that were unexpected or challenged
   an assumption the team held before the incident. These are the
   most valuable lessons — the ones that change mental models.

5. OPEN QUESTIONS
   Questions this incident raised that are not yet answered.
   These are not action items — they are invitations to investigate.
   Derive from the instrumentation gaps and unknowns in the log analysis.

6. RECOMMENDED SHARING
   Which other teams or services at Globalmatics should read this
   and why — based on the specific failure patterns found in the logs.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT INSTRUCTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Produce all three documents in full, in the order above
- Separate each document with a clear heading
- Use [UNKNOWN — requires investigation] wherever the log analysis
  identified a gap rather than speculating
- Use [PLACEHOLDER] for any value that must be filled in by the team
  (revenue figures, customer names, specific owner names)
- Flag any action item that could not be derived from the log analysis
  with [ASSUMPTION] so the team knows to validate it
- Tone: professional, blameless, factual throughout
  — no speculative language, no individual blame