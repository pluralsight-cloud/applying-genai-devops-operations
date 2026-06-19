Here is the Terraform configuration for our EKS cluster and
payment API infrastructure at Globalmatics:

Files are located in the terraform directory.

Using this configuration, generate an operational runbook that covers:
  1. How to safely scale the number of EKS worker nodes up and down
  2. How to update the payment API to a new Docker image
  3. How to roll back a Terraform change that caused a problem
  4. How to destroy and recreate the environment safely

For each procedure include the exact Terraform and AWS CLI commands,
the order to run them, and what to verify after each step.

Here is the Kubernetes deployment manifest for our payment API:

Files are located int eh k8s directory

Generate an operational runbook for the following day-to-day
procedures:
  1. Deploying a new version of the payment API
  2. Rolling back to the previous deployment
  3. Scaling the deployment up and down manually
  4. Restarting all pods without downtime
  5. Checking the health and readiness of the deployment

Use the exact deployment name, namespace, container name, and
port values from the manifest above. Include the kubectl command
for each step and describe what a successful output looks like

Here is the Dockerfile for our Node.js payment API:

The Dockerfile is located in app directory.

Generate an operational runbook for the image build and release process:
  1. How to build the image locally for testing
  2. How to run the container locally and verify it starts correctly
  3. How to tag and push the image to our ECR registry
  4. How to confirm the correct image is running on EKS after a deploy
  5. What to check if the container fails to start

Use the base image, exposed port, and entrypoint values from the
Dockerfile above. Include the exact Docker and AWS CLI commands
for each step.

Here is our Jenkins pipeline configuration for the payment API:

Files are located in the jenkins directory.

Generate an operational runbook that covers:
  1. What each stage in the pipeline does and in what order
  2. How to manually trigger a pipeline run for a specific branch
  3. How to diagnose and recover from a failed pipeline stage
  4. How to roll back a deployment if the pipeline completes
     successfully but the release is bad
  5. Who to notify and what information to collect if the pipeline
     fails in production

Reference the actual stage names and environment variable names
from the pipeline above.

Output MD files to a directory called runbooks.