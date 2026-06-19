Generate a troubleshooting guide for payment API pods going into
CrashLoopBackOff on our EKS cluster.

Our stack:
  - Node.js payment API
  - AWS EKS (Terraform-managed)
  - Docker image stored in ECR
  - Prometheus + Grafana for monitoring

Structure the guide as a decision tree:
  - Start from the symptom: pod is in CrashLoopBackOff
  - Branch based on what the logs show
  - For each branch: list the likely cause, the diagnostic
    commands to confirm it, and the fix
  - End each branch with how to verify the pod is healthy

Include the exact kubectl commands at every step.

Here are the error logs from our payment API pods over the last
24 hours. Several different failure patterns are visible:

```
{"timestamp":"2024-11-29T14:03:12.441Z","level":"info","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Server started","port":3000,"env":"prod"}
{"timestamp":"2024-11-29T14:03:14.882Z","level":"info","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Health check passed","route":"/health","status":200,"duration_ms":2}
{"timestamp":"2024-11-29T14:03:45.119Z","level":"info","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment processed","route":"/api/v1/payments","method":"POST","status":200,"duration_ms":143,"transaction_id":"txn_8f3kd92m","payment_method":"card","currency":"USD","amount":199.99}
{"timestamp":"2024-11-29T14:04:01.334Z","level":"info","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment processed","route":"/api/v1/payments","method":"POST","status":200,"duration_ms":118,"transaction_id":"txn_2p7qr41x","payment_method":"card","currency":"USD","amount":54.00}
{"timestamp":"2024-11-29T14:04:22.560Z","level":"warn","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment declined","route":"/api/v1/payments","method":"POST","status":402,"duration_ms":201,"transaction_id":"txn_9c1ms73n","reason":"insufficient_funds","payment_method":"card","currency":"USD","amount":899.00}
{"timestamp":"2024-11-29T14:04:45.772Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Authentication failed","route":"/api/v1/payments","method":"POST","status":401,"duration_ms":12,"error":"Invalid or expired API key","client_ip":"203.0.113.42"}
{"timestamp":"2024-11-29T14:04:46.003Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Authentication failed","route":"/api/v1/payments","method":"POST","status":401,"duration_ms":9,"error":"Invalid or expired API key","client_ip":"203.0.113.42"}
{"timestamp":"2024-11-29T14:04:46.198Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Authentication failed","route":"/api/v1/payments","method":"POST","status":401,"duration_ms":8,"error":"Invalid or expired API key","client_ip":"203.0.113.42"}
{"timestamp":"2024-11-29T14:04:46.441Z","level":"warn","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Rate limit threshold approaching","client_ip":"203.0.113.42","requests_per_minute":58,"limit":60}
{"timestamp":"2024-11-29T14:05:03.881Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Request validation failed","route":"/api/v1/payments","method":"POST","status":400,"duration_ms":6,"error":"Missing required field: currency","transaction_id":null}
{"timestamp":"2024-11-29T14:05:17.225Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Upstream processor timeout","route":"/api/v1/payments","method":"POST","status":504,"duration_ms":5003,"error":"Payment processor did not respond within 5000ms","transaction_id":"txn_4v8nt61k","upstream":"processor-gateway","retry_attempt":1}
{"timestamp":"2024-11-29T14:05:17.441Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Upstream processor timeout","route":"/api/v1/payments","method":"POST","status":504,"duration_ms":5001,"error":"Payment processor did not respond within 5000ms","transaction_id":"txn_4v8nt61k","upstream":"processor-gateway","retry_attempt":2}
{"timestamp":"2024-11-29T14:05:17.669Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment failed after max retries","route":"/api/v1/payments","method":"POST","status":502,"duration_ms":10009,"transaction_id":"txn_4v8nt61k","retries_exhausted":true}
{"timestamp":"2024-11-29T14:05:33.114Z","level":"info","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment processed","route":"/api/v1/payments","method":"POST","status":200,"duration_ms":162,"transaction_id":"txn_7h2wz88s","payment_method":"card","currency":"USD","amount":30.00}
{"timestamp":"2024-11-29T14:05:51.009Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Unhandled exception","route":"/api/v1/refunds","method":"POST","status":500,"duration_ms":87,"transaction_id":"txn_1q5jp29r","error":"TypeError: Cannot read properties of undefined (reading 'original_amount')","stack":"TypeError: Cannot read properties of undefined (reading 'original_amount')\n    at RefundService.validate (/app/src/services/refund.service.js:142:38)\n    at processRefund (/app/src/controllers/refund.controller.js:67:24)\n    at Layer.handle [as handle_request] (/app/node_modules/express/lib/router/layer.js:95:5)\n    at next (/app/node_modules/express/lib/router/route.js:144:13)"}
{"timestamp":"2024-11-29T14:06:08.773Z","level":"warn","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Slow response detected","route":"/api/v1/payments","method":"POST","status":200,"duration_ms":1843,"transaction_id":"txn_6m3yk55b","threshold_ms":1000}
{"timestamp":"2024-11-29T14:06:09.002Z","level":"warn","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Slow response detected","route":"/api/v1/payments","method":"POST","status":200,"duration_ms":2102,"transaction_id":"txn_0r9xd14c","threshold_ms":1000}
{"timestamp":"2024-11-29T14:06:09.441Z","level":"warn","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Slow response detected","route":"/api/v1/payments","method":"POST","status":200,"duration_ms":2489,"transaction_id":"txn_5k7lb32w","threshold_ms":1000}
{"timestamp":"2024-11-29T14:06:10.118Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment processing error","route":"/api/v1/payments","method":"POST","status":500,"duration_ms":3301,"transaction_id":"txn_2n8qc77f","error":"ETIMEDOUT: connection timed out","upstream":"processor-gateway"}
{"timestamp":"2024-11-29T14:06:10.334Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment processing error","route":"/api/v1/payments","method":"POST","status":500,"duration_ms":3287,"transaction_id":"txn_3t1mp88h","error":"ETIMEDOUT: connection timed out","upstream":"processor-gateway"}
{"timestamp":"2024-11-29T14:06:10.559Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment processing error","route":"/api/v1/payments","method":"POST","status":500,"duration_ms":3412,"transaction_id":"txn_9a4ru55q","error":"ETIMEDOUT: connection timed out","upstream":"processor-gateway"}
{"timestamp":"2024-11-29T14:06:10.781Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Error rate threshold breached","error_rate_pct":34.2,"window_seconds":60,"status":"degraded"}
{"timestamp":"2024-11-29T14:06:11.002Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Payment processing error","route":"/api/v1/payments","method":"POST","status":500,"duration_ms":3389,"transaction_id":"txn_7c2sw19j","error":"ETIMEDOUT: connection timed out","upstream":"processor-gateway"}
{"timestamp":"2024-11-29T14:06:29.667Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Route not found","route":"/api/v2/payments","method":"POST","status":404,"duration_ms":3,"error":"Cannot POST /api/v2/payments"}
{"timestamp":"2024-11-29T14:06:44.221Z","level":"warn","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Memory usage high","heap_used_mb":221,"heap_total_mb":256,"rss_mb":289,"threshold_mb":230}
{"timestamp":"2024-11-29T14:06:58.003Z","level":"warn","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Memory usage high","heap_used_mb":244,"heap_total_mb":256,"rss_mb":301,"threshold_mb":230}
{"timestamp":"2024-11-29T14:07:02.119Z","level":"error","service":"payment-api","version":"a3f9c12","pod":"payment-api-7d9f8b-xkp2q","namespace":"payment-api","msg":"Process OOMKilled","heap_used_mb":256,"heap_total_mb":256,"rss_mb":312,"signal":"SIGKILL"}
```

Analyze these logs and:
  1. Identify the distinct failure patterns present
  2. For each pattern: explain what is likely causing it
  3. Generate a troubleshooting guide that starts from each
     error message and walks through how to diagnose and fix it
  4. Note any patterns that appear related — where one failure
     may be causing another

Generate a troubleshooting guide for failed deployments of the
payment API on EKS.

Our deployment process:
  - Jenkins pipeline builds and pushes a Docker image to ECR
  - Terraform applies changes to the EKS cluster
  - Kubernetes rolls out the new deployment manifest

Cover the following failure scenarios:
  1. The Jenkins pipeline fails during the build stage
  2. The image pushes to ECR but pods fail to pull it on EKS
  3. The new pods start but fail their readiness probes
  4. The deployment rolls out but the new version returns errors
  5. Terraform apply fails mid-way through a change

For each scenario: the symptoms an engineer would see, the
diagnostic commands to run, the most likely cause, and the fix.

Output as MD files in a directory called troubleshooting-guides.