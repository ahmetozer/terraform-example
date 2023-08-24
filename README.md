# Terraform Example

- The EKS cluster runs on ARM architecture and IPv6-supported VPC.
- Custom ecr pull through cache and vpce enabled to use private only network.
- ALB controller installed with helm, changes made to supports to work on private nodes (no internet access)

```bash
terraform init

terraform plan

terraform apply -auto-approve

terraform apply -destroy

```
