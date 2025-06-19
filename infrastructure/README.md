
# Infrastructure Setup for ROR App

## 🚀 Deployment Steps

1. **Set GitHub Secrets**:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Push this repo to GitHub**

3. GitHub Actions will:
   - Build Docker image
   - Push to ECR
   - Deploy infra via Terraform

4. ✅ Access the Load Balancer DNS output by Terraform

## 📦 Environment Variables

ECS Task will use the following:

- `RDS_DB_NAME`, `RDS_USERNAME`, `RDS_PASSWORD`, `RDS_HOSTNAME`, `RDS_PORT`
- `S3_BUCKET_NAME`, `S3_REGION_NAME`, `LB_ENDPOINT`

All injected from Terraform.
