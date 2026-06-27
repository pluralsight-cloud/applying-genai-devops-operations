#!/bin/bash

# ── Configuration ─────────────────────────────────────────
CLUSTER_NAME="[YOUR_CLUSTER_NAME]"
NODEGROUP_NAME="[YOUR_NODEGROUP_NAME]"
ASG_NAME="[YOUR_ASG_NAME]"
ECR_REPO_NAME="payment-api"
BILLING_DIR="./billing"
START_90=$(date -u -d '90 days ago' +%Y-%m-%d)
START_30=$(date -u -d '30 days ago' +%Y-%m-%d)
END_TODAY=$(date -u +%Y-%m-%d)
MONTH_END=$(date -u -d 'last day of this month' +%Y-%m-%d)
# ──────────────────────────────────────────────────────────

echo "Creating billing directory..."
mkdir -p $BILLING_DIR

echo "Collecting monthly cost by service (3 months)..."
aws ce get-cost-and-usage \
  --time-period Start=$START_90,End=$END_TODAY \
  --granularity MONTHLY \
  --metrics BlendedCost UnblendedCost UsageQuantity \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json > $BILLING_DIR/cost-by-service.json

echo "Collecting cost by environment tag..."
aws ce get-cost-and-usage \
  --time-period Start=$START_90,End=$END_TODAY \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment \
  --output json > $BILLING_DIR/cost-by-environment.json

echo "Collecting cost by team tag..."
aws ce get-cost-and-usage \
  --time-period Start=$START_90,End=$END_TODAY \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Team \
  --output json > $BILLING_DIR/cost-by-team.json

echo "Collecting daily cost trend (30 days)..."
aws ce get-cost-and-usage \
  --time-period Start=$START_30,End=$END_TODAY \
  --granularity DAILY \
  --metrics BlendedCost \
  --output json > $BILLING_DIR/cost-daily-trend.json

echo "Collecting month-end forecast..."
aws ce get-cost-forecast \
  --time-period Start=$END_TODAY,End=$MONTH_END \
  --metric BLENDED_COST \
  --granularity MONTHLY \
  --output json > $BILLING_DIR/cost-forecast.json

echo "Collecting Savings Plans utilisation..."
aws ce get-savings-plans-utilization \
  --time-period Start=$START_90,End=$END_TODAY \
  --output json > $BILLING_DIR/savings-plans-utilization.json

echo "Collecting Savings Plans coverage..."
aws ce get-savings-plans-coverage \
  --time-period Start=$START_90,End=$END_TODAY \
  --output json > $BILLING_DIR/savings-plans-coverage.json

echo "Collecting Reserved Instance utilisation..."
aws ce get-reservation-utilization \
  --time-period Start=$START_90,End=$END_TODAY \
  --output json > $BILLING_DIR/reserved-instance-utilization.json

echo "Collecting purchase type split..."
aws ce get-cost-and-usage \
  --time-period Start=$START_90,End=$END_TODAY \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=PURCHASE_TYPE \
  --output json > $BILLING_DIR/cost-by-purchase-type.json

echo "Collecting linked account costs..."
aws ce get-cost-and-usage \
  --time-period Start=$START_30,End=$END_TODAY \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=LINKED_ACCOUNT \
  --output json > $BILLING_DIR/cost-by-account.json

echo "Collecting Compute Optimizer EC2 recommendations..."
aws compute-optimizer get-ec2-instance-recommendations \
  --output json > $BILLING_DIR/compute-optimizer-ec2.json

echo "Collecting Compute Optimizer ASG recommendations..."
aws compute-optimizer get-auto-scaling-group-recommendations \
  --output json > $BILLING_DIR/compute-optimizer-asg.json

echo "Collecting cost anomalies..."
aws ce get-anomalies \
  --date-interval StartDate=$START_90,EndDate=$END_TODAY \
  --output json > $BILLING_DIR/cost-anomalies.json

echo "Collecting EBS volume details..."
aws ec2 describe-volumes \
  --query "Volumes[*].{ID:VolumeId,Size:Size,Type:VolumeType,State:State,IOPS:Iops,Attachment:Attachments[0].State}" \
  --output json > $BILLING_DIR/ebs-volumes.json

echo "Collecting EBS snapshots..."
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[*].{ID:SnapshotId,Size:VolumeSize,StartTime:StartTime,Description:Description}" \
  --output json > $BILLING_DIR/ebs-snapshots.json

echo "Collecting ECR repositories..."
aws ecr describe-repositories \
  --query "repositories[*].{Name:repositoryName,URI:repositoryUri,Created:createdAt}" \
  --output json > $BILLING_DIR/ecr-repositories.json

echo "Collecting untagged ECR images..."
aws ecr list-images \
  --repository-name $ECR_REPO_NAME \
  --filter tagStatus=UNTAGGED \
  --output json > $BILLING_DIR/ecr-untagged-images.json

echo "Collecting EKS cluster details..."
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --output json > $BILLING_DIR/eks-cluster.json

echo "Collecting EKS node group details..."
aws eks describe-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODEGROUP_NAME \
  --output json > $BILLING_DIR/eks-nodegroup.json

echo "Collecting EC2 worker node details..."
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,LaunchTime:LaunchTime,AZ:Placement.AvailabilityZone}" \
  --output json > $BILLING_DIR/ec2-worker-nodes.json

echo "Collecting NAT Gateway data transfer..."
aws cloudwatch get-metric-statistics \
  --namespace AWS/NatGateway \
  --metric-name BytesOutToDestination \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 2592000 \
  --statistics Sum \
  --output json > $BILLING_DIR/nat-gateway-transfer.json

echo "Writing manifest..."
cat > $BILLING_DIR/manifest.json <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reporting_period": {
    "start_90_days": "$START_90",
    "start_30_days": "$START_30",
    "end": "$END_TODAY"
  },
  "cluster_name": "$CLUSTER_NAME",
  "ecr_repo": "$ECR_REPO_NAME",
  "files": [
    "cost-by-service.json",
    "cost-by-environment.json",
    "cost-by-team.json",
    "cost-daily-trend.json",
    "cost-forecast.json",
    "savings-plans-utilization.json",
    "savings-plans-coverage.json",
    "reserved-instance-utilization.json",
    "cost-by-purchase-type.json",
    "cost-by-account.json",
    "compute-optimizer-ec2.json",
    "compute-optimizer-asg.json",
    "cost-anomalies.json",
    "ebs-volumes.json",
    "ebs-snapshots.json",
    "ecr-repositories.json",
    "ecr-untagged-images.json",
    "eks-cluster.json",
    "eks-nodegroup.json",
    "ec2-worker-nodes.json",
    "nat-gateway-transfer.json"
  ]
}
EOF

echo ""
echo "Done. Billing data saved to $BILLING_DIR/"
echo "Files collected:"
ls -lh $BILLING_DIR/