# Terraform Example

- VPC (infrastructure.tf)
  - IPv6
  - Internet Gateway for DualStack (IPv4 and IPv6) and Egress only gateway for IPv6
  - Subnet
        - IPv6 only Private, Public, Egress
        - DualStack  Private, Public, Egress (EKS allocated here)
  - Route Table (Private, Public, Egress)
  - Security Group
        - Default security group
        - Internal Only
  - Endpoint services  
  Enable aws services for private network and reduce ip-transit cost
        - ec2
        - ecr api
        - ecr dkr
        - sts (used by k8s service account)
        - elasticloadbalancing
        - instance_connect_endpoint (Commented due to creation time duration)
- EKS cluster (kubernetes-cluster.tf)
  - ARM architecture
  - IPv6
  - OIDC
  - Node Group
        - Private
        - Public
  - ECR Pull Through Cache
  - EKS addon (vpc-cni)
  - AWS load balancer controler (kubernetes-aws-load-balancer.tf)
    Currenty this controlelr does not supported as addon, it is installed with helm
    - IAM role
    - Support private repository to run service pods at internal network (#bk5Iutho2)
    - Public Security group
      - Allow public to ALB 80, 443
      - Allow ALB to public ICMP  
      ping command will not work because incoming ICMP not enabled to prevent net scan but ICMP response enabled for connection errors.
      - Permit access to EKS
        - Allow all outgoing traffic to EKS cluster
        - Permit this sg at EKS sg to pods for  tcp/80, tcp/8080 and icmp
        - Permit EKS sg to ALB for ICMP (prevent connection hang)

- Custom ecr pull through cache and vpce enabled to use private only network.
- ALB controller installed with helm, changes made to supports to work on private nodes (no internet access)

```bash
terraform init

terraform plan

terraform apply -auto-approve # it will take 15-25 min

terraform apply -destroy # Delete all resources

```
