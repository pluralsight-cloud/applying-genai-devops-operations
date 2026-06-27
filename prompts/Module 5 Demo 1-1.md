# Module 5 — Demo 1 (Part 1): Collect live AWS cost and usage data

Run the AWS CLI commands below and **save the output to a folder called `cost-management`**. This raw data becomes the evidence base for the cost optimization report generated in Part 2.

> Replace every `[PLACEHOLDER]` (for example `[CLUSTER_NAME]`, `[NODEGROUP_NAME]`, `[ASG_NAME]`, `[ECR_REPO_NAME]`) with the real values for your environment before running.

---

## 1. EKS cluster and node group details

```bash
aws eks describe-cluster --name [CLUSTER_NAME] --output json
aws eks list-nodegroups --cluster-name [CLUSTER_NAME] --output json
aws eks describe-nodegroup --cluster-name [CLUSTER_NAME] --nodegroup-name [NODEGROUP_NAME] --output json
```

## 2. EC2 instances (EKS worker nodes)

```bash
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=[CLUSTER_NAME]" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,LaunchTime:LaunchTime,AZ:Placement.AvailabilityZone}" \
  --output table
```

## 3. CloudWatch CPU utilisation for EKS nodes (last 14 days)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=[ASG_NAME] \
  --start-time $(date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 \
  --statistics Average Maximum \
  --output table
```

## 4. EBS volumes (find unattached and gp2 volumes)

```bash
aws ec2 describe-volumes \
  --query "Volumes[*].{ID:VolumeId,Size:Size,Type:VolumeType,State:State,IOPS:Iops,Attachments:Attachments[0].State}" \
  --output table
```

## 5. EBS snapshots owned by this account

```bash
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[*].{ID:SnapshotId,Size:VolumeSize,StartTime:StartTime,Description:Description}" \
  --output table
```

## 6. Load balancers

```bash
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[*].{Name:LoadBalancerName,Type:Type,State:State.Code,DNS:DNSName,Created:CreatedTime}" \
  --output table
```

## 7. Load balancer target group health (identify idle load balancers)

```bash
aws elbv2 describe-target-groups --output json
```

## 8. ECR repositories and image count

```bash
aws ecr describe-repositories \
  --query "repositories[*].{Name:repositoryName,URI:repositoryUri,Created:createdAt}" \
  --output table
```

## 9. ECR images (find old and untagged images)

```bash
aws ecr list-images \
  --repository-name [ECR_REPO_NAME] \
  --filter tagStatus=UNTAGGED \
  --query "imageIds[*].imageDigest" \
  --output table
```

## 10. Data transfer (NAT Gateway usage)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/NatGateway \
  --metric-name BytesOutToDestination \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 2592000 \
  --statistics Sum \
  --output table
```

## 11. Savings Plans and Reserved Instance coverage

```bash
aws ce get-savings-plans-coverage \
  --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --output json
```

## 12. Current month cost breakdown by service

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json
```

## 13. Right-sizing recommendations from AWS Compute Optimizer

```bash
aws compute-optimizer get-ec2-instance-recommendations \
  --output json

aws compute-optimizer get-auto-scaling-group-recommendations \
  --output json
```
