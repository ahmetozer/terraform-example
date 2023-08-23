
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
  version = "1.27"

  vpc_config {
    //subnet_ids = [aws_subnet.kadikoy_ipv6_public[*].id, aws_subnet.kadikoy_ipv6_egress_only.*.id, aws_subnet.kadikoy_ipv6_private.*.id]
    subnet_ids =  concat(aws_subnet.kadikoy_ds_public.*.id, aws_subnet.kadikoy_ds_private.*.id)
  }

  
  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.kadikoy-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.kadikoy-AmazonEKSVPCResourceController,
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

resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_kadikoy_node_group.name
}

resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_kadikoy_node_group.name
}

resource "aws_iam_role_policy_attachment" "kadikoy-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_kadikoy_node_group.name
}

