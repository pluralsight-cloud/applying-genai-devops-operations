# Module 5 — Demo 2: Executive-ready cost reporting from raw AWS billing data

Use the prompt below with your GenAI tool to turn raw AWS billing exports into **three audience-tailored cost documents** — an executive summary, an engineering breakdown, and an optimization roadmap.

---

## Role

You are a senior cloud financial analyst producing executive-ready cost reporting for Globalmatics from raw AWS billing data.

---

## Company context

- Globalmatics operates a B2B payment processing platform on AWS EKS
- **Primary workloads:** payment API (production), Prometheus + Grafana (monitoring), Jenkins (CI/CD), Terraform-managed infrastructure
- **AWS region:** `us-east-1`
- **Environments:** production, staging, dev (tagged by `Environment` tag)
- **Monthly budget:** `[MONTHLY_BUDGET_USD]`
- **Reporting period:** `[MONTH / QUARTER]`
- **Currency:** USD

---

## Billing data location

All source files are in the `billing/` directory. Read each file listed below before producing any output. **Do not proceed if a file is missing** — flag it and state which section it affects.

| File | Contents | Used in |
|------|----------|---------|
| `manifest.json` | Reporting period, generation timestamp, cluster details. **Read this first.** | — |
| `cost-by-service.json` | Monthly cost grouped by AWS service over 3 months | Doc 1 (cost drivers), Doc 2 (service table) |
| `cost-by-environment.json` | Monthly cost grouped by `Environment` tag (prod/staging/dev) | Doc 1 (environment split), Doc 2 (by environment) |
| `cost-by-team.json` | Monthly cost grouped by `Team` tag | Doc 2 (cost by team), Doc 3 (tagging compliance) |
| `cost-daily-trend.json` | Daily cost for the last 30 days | Doc 2 (daily trend analysis) |
| `cost-forecast.json` | Projected spend through end of current month | Doc 1 (headline numbers) |
| `savings-plans-utilization.json` | Savings Plans utilisation rate over 3 months | Doc 2 (purchase type efficiency) |
| `savings-plans-coverage.json` | Percentage of eligible spend covered by Savings Plans | Doc 1 (cost efficiency), Doc 3 (medium-term actions) |
| `reserved-instance-utilization.json` | Reserved Instance utilisation over 3 months | Doc 2 (purchase type efficiency) |
| `cost-by-purchase-type.json` | On-demand vs Savings Plans vs Reserved split | Doc 1 (cost efficiency indicator) |
| `cost-by-account.json` | Cost by linked AWS account | Doc 2 (cost breakdown) |
| `compute-optimizer-ec2.json` | EC2 rightsizing recommendations from Compute Optimizer | Doc 2 (rightsizing signal), Doc 3 (medium-term) |
| `compute-optimizer-asg.json` | Auto Scaling Group recommendations from Compute Optimizer | Doc 3 (medium-term actions) |
| `cost-anomalies.json` | Detected cost anomalies over the last 90 days | All three documents — flag prominently if anomalies exist |
| `ebs-volumes.json` | EBS volume inventory (type, state, attachment) | Doc 3 (quick wins — gp2→gp3, unattached volumes) |
| `ebs-snapshots.json` | EBS snapshot inventory with age and size | Doc 3 (quick wins — snapshot cleanup) |
| `ecr-repositories.json` | ECR repository inventory | Doc 3 (quick wins — image cleanup) |
| `ecr-untagged-images.json` | Untagged ECR images in the payment-api repository | Doc 3 (quick wins — image cleanup) |
| `eks-cluster.json` | EKS cluster configuration and version | Doc 2 (infrastructure context) |
| `eks-nodegroup.json` | EKS node group configuration (instance types, scaling limits) | Doc 3 (medium-term — rightsizing) |
| `ec2-worker-nodes.json` | Running EC2 instances backing the EKS cluster | Doc 2 (rightsizing signal) |
| `nat-gateway-transfer.json` | NAT Gateway data transfer volume over 30 days | Doc 2 (cost by service), Doc 3 (strategic) |

---

## Document 1 — Executive financial summary

> **Audience:** CEO, CFO, Board
> **Length:** One page
> **Tone:** Business language only — no AWS service names, no technical jargon. Translate every technical term.

**Source files:** `cost-by-service.json`, `cost-by-environment.json`, `cost-daily-trend.json`, `cost-forecast.json`, `cost-by-purchase-type.json`, `cost-anomalies.json`

**1. Headline numbers**

| Metric | Value |
|--------|-------|
| This month | `$[X]` (from `cost-by-service.json`) |
| Last month | `$[X]` (`[+/-]%` change) |
| 3-month average | `$[X]` |
| Budget | `$[MONTHLY_BUDGET_USD]` |
| Budget variance | `$[X]` (`[over/under]` by `[%]`) |
| End-of-month forecast | `$[X]` (from `cost-forecast.json`) |

**2. What drove the cost**

Three bullet points maximum. Each bullet:

- Names the cost driver in business terms, not AWS terms
- States the dollar amount and percentage of total spend
- Explains in one sentence why this cost exists

**3. Month-over-month narrative**

One paragraph (4–5 sentences):

- Whether spend increased or decreased vs last month
- Primary reason for the change
- Whether the change was planned or unexpected
- Whether the current trajectory puts the quarter at risk

If `cost-anomalies.json` contains anomalies, surface the most significant one here with ⚠️ and a business-language explanation.

**4. Environment cost split**

Derived from `cost-by-environment.json`:

- Production: `[X]%` (`$[X]`)
- Staging: `[X]%` (`$[X]`)
- Development: `[X]%` (`$[X]`)

One sentence on whether the non-production ratio is appropriate.

**5. Cost efficiency indicator**

Derived from `cost-by-purchase-type.json`, `savings-plans-coverage.json`: state what percentage of spend is covered by committed pricing vs on-demand. Translate to plain English — no "Savings Plans" or "Reserved Instances" terminology.

**6. Three things to know**

The three most important facts a CEO or CFO needs to act on. Two sentences maximum each. Zero technical terms.

---

## Document 2 — Engineering cost breakdown

> **Audience:** CTO, VP Engineering, Engineering Leads
> **Length:** Two to three pages
> **Tone:** Technical but structured — AWS service names are acceptable, explain jargon in parentheses

**Source files:** `cost-by-service.json`, `cost-by-environment.json`, `cost-by-team.json`, `cost-daily-trend.json`, `savings-plans-utilization.json`, `savings-plans-coverage.json`, `reserved-instance-utilization.json`, `cost-by-purchase-type.json`, `compute-optimizer-ec2.json`, `ec2-worker-nodes.json`, `eks-nodegroup.json`, `nat-gateway-transfer.json`, `cost-anomalies.json`

**1. Cost by service — ranked table**

Derived from `cost-by-service.json`.

| AWS Service | This Month | Last Month | 3-Month Avg | % of Total | Trend |
|-------------|-----------|-----------|-------------|-----------|-------|

Trend: ↑ increasing  ↓ decreasing  → stable. Include every service above $10/month. One sentence below the table on the top two cost drivers.

**2. Cost by environment**

Derived from `cost-by-environment.json`. For each environment:

- Total monthly spend
- Top 3 services in that environment
- Month-over-month change and reason if determinable

**3. Cost by team**

Derived from `cost-by-team.json`.

| Team | This Month | Last Month | Primary Service | Notes |
|------|-----------|-----------|-----------------|-------|

If team tags are absent or incomplete, calculate the percentage of untagged spend and flag it explicitly.

**4. Daily spend trend analysis**

Derived from `cost-daily-trend.json` and `cost-anomalies.json`:

- Average daily spend
- Highest single-day cost and date
- Any spikes above 1.5× daily average
- Overall 30-day trajectory: flat / growing / declining
- Any anomaly from `cost-anomalies.json`: describe service, start date, and estimated excess cost with ⚠️

**5. Purchase type efficiency**

Derived from `savings-plans-utilization.json`, `savings-plans-coverage.json`, `reserved-instance-utilization.json`, `cost-by-purchase-type.json`:

- On-demand spend this month: `$[X]` (`[%]` of total)
- Savings Plans coverage: `[%]` of eligible spend
- Reserved Instance utilisation: `[%]`

Flag any committed pricing under 80% utilisation.

**6. Rightsizing signal**

Derived from `compute-optimizer-ec2.json`, `compute-optimizer-asg.json`, `eks-nodegroup.json`:

- Number of resources with recommendations
- Total estimated monthly saving
- Top 3 specific recommendations: current vs recommended type, saving per resource

**7. Unit economics**

Derived from `cost-by-service.json` and `cost-forecast.json`:

- Cost per day of production uptime
- Infrastructure spend as % of `[MONTHLY_BUDGET_USD]`
- Cost per transaction if transaction volume is provided: `[PASTE_TRANSACTION_VOLUME_HERE` — omit section if unavailable`]`

---

## Document 3 — Cost optimization roadmap

> **Audience:** Engineering Leads, Platform Team, Finance
> **Length:** Two pages
> **Tone:** Action-oriented — every item has a specific command or file change, an owner, and a date

**Source files:** `ebs-volumes.json`, `ebs-snapshots.json`, `ecr-untagged-images.json`, `ecr-repositories.json`, `compute-optimizer-ec2.json`, `compute-optimizer-asg.json`, `savings-plans-coverage.json`, `cost-by-team.json`, `eks-nodegroup.json`, `nat-gateway-transfer.json`

**1. Optimization summary**

| Metric | Value |
|--------|-------|
| Current monthly spend | `$[X]` |
| Estimated saving — quick wins only | `$[X]/month` |
| Estimated saving — all recommendations | `$[X]/month` |

**2. Quick wins**

Derived from `ebs-volumes.json`, `ebs-snapshots.json`, `ecr-untagged-images.json`. For each quick win:

- ID: QW-001, QW-002, etc.
- Action, Service, Estimated monthly saving, Effort (hours)
- Exact AWS CLI command or Terraform HCL change
- Verification: how to confirm the saving in the next bill

Cover only items evidenced in the billing files:

- gp2 → gp3 EBS migration (from `ebs-volumes.json`)
- Unattached EBS volume deletion (from `ebs-volumes.json`)
- Old snapshot cleanup (from `ebs-snapshots.json`)
- ECR untagged image deletion (from `ecr-untagged-images.json`)
- ECR lifecycle policy creation (from `ecr-repositories.json`)

**3. Medium-term actions**

Derived from `compute-optimizer-ec2.json`, `compute-optimizer-asg.json`, `savings-plans-coverage.json`, `eks-nodegroup.json`. Same format as quick wins, plus:

- Risk: what could go wrong
- Prerequisite: what must be validated first

Cover only items evidenced in the billing files:

- EC2 / EKS node rightsizing from Compute Optimizer
- Savings Plans purchase:
  - Recommended hourly commitment derived from `savings-plans-coverage.json` coverage gap
  - Estimated annual saving vs current on-demand
  - Risk: cite daily trend variability from `cost-daily-trend.json` before committing
- EKS node group max scaling limit review (from `eks-nodegroup.json` — flag if no upper bound is set)

**4. Strategic actions**

Derived from `nat-gateway-transfer.json`, `cost-by-purchase-type.json`. For each:

- Description, current cost, target cost after change
- Dependencies and required decision maker

Include only items supported by the billing data.

**5. Tagging compliance report**

Derived from `cost-by-team.json`, `cost-by-environment.json`:

- Total untagged spend this month: `$[X]` (`[%]`)
- Required tags: `Environment`, `Team`, `Service`, `CostCenter`
- AWS CLI command to enable a Config rule enforcing tags:

```bash
aws configservice put-config-rule --config-rule file://required-tags-rule.json
```

- Generate the `required-tags-rule.json` content

**6. Savings tracker**

| ID | Action | Owner Role | Target Date | Status | Saving Realised |
|----|--------|-----------|-------------|--------|-----------------|

Pre-populate with all quick wins and medium-term actions. Status default: `NOT STARTED`.

---

## Output rules

- Read all `billing/` files before writing any section
- Produce all three documents in full, in order
- Cite the source file for every figure, e.g. `"$1,240 (billing/cost-by-service.json, November)"`
- Use `[INSUFFICIENT DATA — billing/filename.json]` where a file does not contain enough detail to populate a section
- Use `[PLACEHOLDER]` for values the team must supply
- Flag every cost anomaly with ⚠️ across all three documents
- Document 1: zero AWS service names — translate everything
- Document 3: every action must include a CLI command or Terraform HCL snippet derived from the billing file data
- Do not fabricate or estimate any dollar figure — every number must be traceable to a specific billing file
- Save the three documents to MD files in the `billing` directory
