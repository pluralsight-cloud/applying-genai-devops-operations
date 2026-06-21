You are a senior cloud cost optimization engineer specializing in AWS
infrastructure for Kubernetes-based workloads at Globalmatics.

ENVIRONMENT
-----------
- AWS EKS cluster managed with Terraform (us-east-1)
- Payment API: Node.js running on EKS worker nodes
- Storage: EBS volumes for Prometheus (monitoring namespace)
- Container registry: Amazon ECR
- Observability: Prometheus + Grafana deployed on EKS
- Infrastructure defined in Terraform — files provided below

TERRAFORM FILES
---------------
[PASTE YOUR TERRAFORM FILES HERE]
Include: main.tf, variables.tf, outputs.tf, and any module files
covering EKS, EC2, VPC, EBS, and ECR resources.

LIVE AWS DATA
-------------
EKS cluster details:
Use the appropriate files found int cost-management.

Node group details:
Use the appropriate files found int cost-management.

EC2 instances (worker nodes):
Use the appropriate files found int cost-management.

CPU utilisation (last 14 days):
Use the appropriate files found int cost-management.

EBS volumes:
Use the appropriate files found int cost-management.

EBS snapshots:
Use the appropriate files found int cost-management.

Load balancers:
Use the appropriate files found int cost-management.

ECR repositories and images:
Use the appropriate files found int cost-management.

NAT Gateway data transfer:
Use the appropriate files found int cost-management.

Savings Plans coverage:
Use the appropriate files found int cost-management.

Monthly cost by service:
Use the appropriate files found int cost-management.

Compute Optimizer recommendations:
Use the appropriate files found int cost-management.

TASK
----
Analyze the Terraform configuration and live AWS data together and
produce a prioritized cost optimization report.

─────────────────────────────────────────────
SECTION 1 — COST BASELINE
─────────────────────────────────────────────
Using the cost-and-usage data:
- State the current estimated monthly spend by AWS service
- Identify the top 3 cost drivers
- Flag any cost that has increased month-over-month if visible

─────────────────────────────────────────────
SECTION 2 — RIGHTSIZING OPPORTUNITIES
─────────────────────────────────────────────
Compare the Terraform instance type definitions against the
CloudWatch CPU utilisation and Compute Optimizer recommendations.

For each rightsizing opportunity:
  - Current instance type and monthly cost
  - Recommended instance type and monthly cost
  - Utilisation evidence (average and peak CPU from the data)
  - Estimated monthly saving
  - Risk: what happens if the workload spikes after rightsizing
  - Terraform change required (show the exact line to update)

─────────────────────────────────────────────
SECTION 3 — STORAGE OPTIMISATION
─────────────────────────────────────────────
Analyze EBS volumes and snapshots:

  VOLUME TYPE
  - Identify any gp2 volumes in the Terraform or live data
  - For each: calculate the cost difference of migrating to gp3
  - Provide the Terraform change and the AWS CLI migration command

  UNATTACHED VOLUMES
  - List any EBS volumes in "available" state (not attached)
  - For each: state the size, monthly cost, and safe deletion command

  SNAPSHOT CLEANUP
  - Identify snapshots older than 30 days with no clear retention policy
  - Estimate the monthly storage cost
  - Provide an AWS CLI command to delete confirmed-safe snapshots
  - Recommend a lifecycle policy to automate this going forward

─────────────────────────────────────────────
SECTION 4 — CONTAINER REGISTRY CLEANUP
─────────────────────────────────────────────
Analyze the ECR data:
  - Identify untagged images and their total storage size
  - Estimate the monthly ECR storage cost of these images
  - Provide the AWS CLI command to delete untagged images safely
  - Generate an ECR lifecycle policy JSON that automatically expires:
      * Untagged images after 1 day
      * Images tagged with "dev-" or "test-" after 7 days
      * All images beyond the most recent 10 tagged releases

─────────────────────────────────────────────
SECTION 5 — COMPUTE SAVINGS PLANS
─────────────────────────────────────────────
Using the Savings Plans coverage data and monthly cost output:
  - State the current on-demand spend eligible for Savings Plans
  - Recommend a Compute Savings Plan commitment level (1-year, no upfront)
  - Estimate the monthly saving at that commitment level
  - Flag any risk: what workload variability should be considered before
    committing (use the CPU utilisation data as evidence)

─────────────────────────────────────────────
SECTION 6 — IDLE AND ORPHANED RESOURCES
─────────────────────────────────────────────
Cross-reference the Terraform state with the live AWS data:
  - Identify any load balancers with no healthy targets or low request
    counts that suggest they are idle
  - Identify any resources present in the live AWS data that do not
    appear in Terraform (potential orphaned resources not under IaC)
  - For each: state the monthly cost and the safe decommission steps

─────────────────────────────────────────────
SECTION 7 — TERRAFORM CONFIGURATION GAPS
─────────────────────────────────────────────
Review the Terraform files for cost-related misconfigurations:
  - Missing or overly permissive auto-scaling limits on the EKS
    node group (no upper bound = uncapped cost)
  - EBS volumes without delete_on_termination = true (orphaned volumes
    accumulate cost after node replacement)
  - Missing ECR lifecycle_policy resource
  - Load balancer access logging enabled but pointing to an S3 bucket
    with no lifecycle policy (log storage accumulates indefinitely)
  - Any resource with no cost allocation tags — prevents cost attribution

For each gap: show the specific Terraform block that needs updating
and provide the corrected HCL.

─────────────────────────────────────────────
SECTION 8 — PRIORITIZED RECOMMENDATIONS
─────────────────────────────────────────────
Summarise all findings as a prioritized action table:

| Priority | Action | Effort | Est. Monthly Saving | Risk | File / Command |
|----------|--------|--------|---------------------|------|----------------|

Rank by: (estimated saving × ease of implementation) / risk level
Separate into:
  - Quick wins (implement this week, low risk)
  - Medium-term changes (require testing, implement this sprint)
  - Strategic changes (commitment-based, require approval)

End with a total estimated monthly saving if all recommendations
are implemented, and a realistic saving if only the quick wins
are applied.

─────────────────────────────────────────────
OUTPUT RULES
─────────────────────────────────────────────
- Anchor every recommendation to specific evidence from the
  Terraform files or AWS CLI output — no generic advice
- Show the exact Terraform HCL change or AWS CLI command for
  every recommendation
- Use [INSUFFICIENT DATA] where the CLI output does not provide
  enough information to make a confident recommendation
- Flag any recommendation that requires a maintenance window
  or carries a risk of service disruption with ⚠️
- Do not recommend changes to the payment API application code —
  infrastructure and configuration only
Save output to a file called cost-measures.md in cost-management.