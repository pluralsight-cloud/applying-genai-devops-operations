You are a senior SRE helping diagnose and resolve errors in a production
payment API at Globalmatics.

ENVIRONMENT
-----------
- Payment API: Node.js / Express running on AWS EKS
- Namespace: payment-api
- Observability: Prometheus + Grafana
- Infrastructure managed with Terraform
- Logs are structured JSON, shipped from pods in real time

ERROR LOGS
----------
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

TASK
----
Analyze the logs above and produce a complete diagnostic report.

1. PATTERN RECOGNITION
   Group the log entries by error type and identify distinct failure
   patterns. For each pattern:
   - Name the pattern (e.g. "upstream processor timeout", "auth failures")
   - List the log entries that belong to it by timestamp
   - State how many times it occurs and over what time window
   - Classify the severity: critical / warning / informational

2. TIMELINE RECONSTRUCTION
   Reconstruct a chronological narrative of what happened in plain
   English based solely on what the logs show. Identify:
   - The earliest signal that something was wrong
   - The point at which the issue became customer-impacting
   - Any cascading effects where one failure appears to trigger another
   - The final state of the pod at the end of the log window

3. ROOT CAUSE ANALYSIS
   Based on the patterns identified, state the most likely root cause.
   - Rank your top 3 hypotheses from most to least likely
   - For each hypothesis: cite the specific log entries that support it
   - Identify any gaps in the log data that prevent a definitive conclusion
   - Flag any log entries that are inconsistent with your root cause theory

4. IMMEDIATE DIAGNOSTIC STEPS
   What should the on-call engineer check right now to confirm the root
   cause? Provide the exact commands:
   - kubectl commands to inspect pod state, events, and resource usage
   - Prometheus queries to correlate the log patterns with metrics
   - Any AWS CLI commands relevant to diagnosing the issue
   
   For each command, state what output confirms the hypothesis and what
   output would rule it out.

5. PROPOSED FIXES
   For each identified root cause, propose a fix at two levels:

   IMMEDIATE (resolve now without a full deploy):
   - The exact kubectl or AWS CLI command to apply
   - Estimated time to take effect
   - Risk: what could go wrong with this fix
   - Rollback: how to undo it if it makes things worse

   PERMANENT (prevents recurrence, requires a code or config change):
   - Which file needs to change: application code, Dockerfile,
     Kubernetes manifest, or Terraform
   - What specifically changes and why
   - How to validate the fix in a non-production environment
     before promoting to production

6. WHAT THE LOGS DO NOT TELL US
   List the information that would be needed to fully diagnose this
   incident but is not present in the logs. For each gap:
   - What is missing
   - Where that information would typically be found
     (e.g. Prometheus metrics, AWS CloudWatch, Grafana dashboard,
     application APM trace)
   - What instrumentation change would capture it in future incidents

7. ALERTING RECOMMENDATIONS
   Based on the failure patterns in these logs, identify any monitoring
   gaps. For each gap propose:
   - A Prometheus alert or log-based alert that would have fired earlier
   - The metric or log pattern to monitor
   - The recommended threshold and severity level

Present findings in order of severity, most critical
Save the results to a md file in a directory called analysis 