# Module 2 — Demo 3: Docker and ECR commands

Replace `<repository>` and `<image_name>` with your ECR registry URL and image tag (for example, `123456789012.dkr.ecr.us-east-1.amazonaws.com/payment-api`).

## Log in to ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <repository>
```

## Build Docker image

```bash
docker image build -t <image_name>:latest .
```

## Push image to ECR

```bash
docker image push <image_name>:latest
```
