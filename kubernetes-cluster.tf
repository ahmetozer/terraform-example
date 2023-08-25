
data "aws_iam_policy_document" "kadikoy_eks_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "kadikoy_eks" {
  name               = "kadikoy-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.kadikoy_eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.kadikoy_eks.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.kadikoy_eks.name
}


resource "aws_eks_cluster" "kadikoy" {
  name     = "kadikoy"
  role_arn = aws_iam_role.kadikoy_eks.arn
  version  = "1.27"

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    //subnet_ids = [aws_subnet.kadikoy_ipv6_public[*].id, aws_subnet.kadikoy_ipv6_egress_only.*.id, aws_subnet.kadikoy_ipv6_private.*.id]
    subnet_ids = concat(aws_subnet.kadikoy_ds_public.*.id, aws_subnet.kadikoy_ds_private.*.id)
  }


  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.kadikoy-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.kadikoy-AmazonEKSVPCResourceController,
    aws_iam_role_policy.kadikoy-ECRPullThroughCache,
    aws_vpc_endpoint.kadikoy-ec2,
    aws_vpc_endpoint.kadikoy-ecr-api,
    aws_vpc_endpoint.kadikoy-ecr-dkr,
    aws_ec2_instance_connect_endpoint.kadikoy,
    aws_ecr_pull_through_cache_rule.kadikoy-cache,
    
  ]
  kubernetes_network_config {
    ip_family = "ipv6"
  }

  tags = {
    Name = "${var.Project}"
  }
}

output "endpoint" {
  value = aws_eks_cluster.kadikoy.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.kadikoy.certificate_authority[0].data
}



resource "aws_iam_role" "eks_kadikoy_node_group" {
  name = "eks-node-group-kadikoy"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

}


resource "aws_iam_policy" "KadikoyAmazonEKS_CNI_IPv6_Policy" {
  name = "Kadikoy_AmazonEKS_CNI_IPv6_Policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:AssignIpv6Addresses",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstanceTypes"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateTags"
        ],
        "Resource" : [
          "arn:aws:ec2:*:*:network-interface/*"
        ]
      }
    ]
  })

}


resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_kadikoy_node_group.name
}

resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_kadikoy_node_group.name
}

resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEKS_CNI_IPv6_Policy" {
  policy_arn = aws_iam_policy.KadikoyAmazonEKS_CNI_IPv6_Policy.arn
  role       = aws_iam_role.eks_kadikoy_node_group.name
  depends_on = [aws_iam_policy.KadikoyAmazonEKS_CNI_IPv6_Policy]
}

resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_kadikoy_node_group.name
}


resource "aws_eks_node_group" "kadikoy_eks_public" {
  cluster_name    = aws_eks_cluster.kadikoy.name
  node_group_name = "public"
  node_role_arn   = aws_iam_role.eks_kadikoy_node_group.arn
  subnet_ids      = aws_subnet.kadikoy_ds_public[*].id
  capacity_type   = "SPOT"
  ami_type        = "BOTTLEROCKET_ARM_64"

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  instance_types = ["t4g.nano", "t4g.micro", "t4g.small", "t4g.medium", "t4g.large"]


  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_eks_cluster.kadikoy
  ]
}

resource "aws_eks_node_group" "kadikoy_eks_private" {
  cluster_name    = aws_eks_cluster.kadikoy.name
  node_group_name = "private"
  node_role_arn   = aws_iam_role.eks_kadikoy_node_group.arn
  subnet_ids      = aws_subnet.kadikoy_ds_private[*].id
  capacity_type   = "SPOT"
  ami_type        = "BOTTLEROCKET_ARM_64"

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }
  instance_types = ["t4g.nano", "t4g.micro", "t4g.small", "t4g.medium", "t4g.large"]

  update_config {
    max_unavailable = 1
  }


  depends_on = [
    aws_eks_cluster.kadikoy,
  ]
}

// Container cache 
resource "aws_ecr_repository" "kadikoy-cache" {
  name = "kadikoy-cache"
}

resource "aws_ecr_lifecycle_policy" "kadikoy-cache" {
  repository = aws_ecr_repository.kadikoy-cache.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 7 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 7
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
  depends_on = [ aws_ecr_repository.kadikoy-cache ]
}

resource "aws_iam_role_policy" "kadikoy-ECRPullThroughCache" {
  name = "kadikoy-ECRPullThroughCache"
  role = aws_iam_role.eks_kadikoy_node_group.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:CreateRepository",
          "ecr:BatchImportUpstreamImage"
        ]
        Effect = "Allow"
        Resource : "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${aws_ecr_repository.kadikoy-cache.name}/*"
      },
    ]
  })
}

// Private nodes not able to get images from public registry
resource "aws_ecr_pull_through_cache_rule" "kadikoy-cache" {
  ecr_repository_prefix = aws_ecr_repository.kadikoy-cache.name
  upstream_registry_url = "public.ecr.aws"
  depends_on = [ aws_ecr_repository.kadikoy-cache ]
}

# Default iam role `arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly` does not support pull through cache


// Example alb controller image
// {data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/kadikoy-cache/eks/aws-load-balancer-controller



resource "aws_eks_addon" "kadikoy_vpc_cni" {
  cluster_name  = aws_eks_cluster.kadikoy.name
  addon_version = "v1.13.4-eksbuild.1"
  addon_name    = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
}

provider "kubernetes" {
  host                   = aws_eks_cluster.kadikoy.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.kadikoy.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.kadikoy.name]
    command     = "aws"
  }

}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.kadikoy.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.kadikoy.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.kadikoy.name]
      command     = "aws"
    }
  }
}
