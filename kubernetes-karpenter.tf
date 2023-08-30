
// "KarpenterNodeRole-${CLUSTER_NAME}" 
# resource "aws_iam_role" "KarpenterNodeRole" {
#   name = "${aws_eks_cluster.kadikoy.name}-KarpenterNodeRole"
#   assume_role_policy = jsonencode({
#     "Version" : "2012-10-17",
#     "Statement" : [
#       {
#         "Effect" : "Allow",
#         "Principal" : {
#           "Service" : "ec2.amazonaws.com"
#         },
#         "Action" : "sts:AssumeRole"
#       }
#     ]
#   })
#   depends_on = [
#     aws_eks_cluster.kadikoy
#   ]
# }

# resource "aws_iam_role_policy_attachment" "karpenter-AmazonEKSWorkerNodePolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.KarpenterNodeRole.name
# }

# resource "aws_iam_role_policy_attachment" "karpenter-AmazonEKS_CNI_Policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.KarpenterNodeRole.name
# }

# resource "aws_iam_role_policy_attachment" "karpenter-AmazonEKS_CNI_IPv6_Policy" {
#   policy_arn = aws_iam_policy.KadikoyAmazonEKS_CNI_IPv6_Policy.arn
#   role       = aws_iam_role.KarpenterNodeRole.name
#   depends_on = [aws_iam_policy.KadikoyAmazonEKS_CNI_IPv6_Policy]
# }

# resource "aws_iam_role_policy_attachment" "karpenter-AmazonEC2ContainerRegistryReadOnly" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.KarpenterNodeRole.name
# }

resource "aws_iam_role_policy_attachment" "karpenter-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks-node-group.name
}

resource "aws_iam_instance_profile" "KarpenterNodeInstanceProfile" {
  name = "KarpenterNodeInstanceProfile-${aws_eks_cluster.kadikoy.name}"
  role = aws_iam_role.eks-node-group.name
}


resource "aws_iam_role" "KarpenterControllerRole" {
  name = "${aws_eks_cluster.kadikoy.name}-KarpenterControllerRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${trimprefix(aws_eks_cluster.kadikoy.identity[0].oidc[0].issuer, "https://")}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${trimprefix(aws_eks_cluster.kadikoy.identity[0].oidc[0].issuer, "https://")}:aud" : "sts.amazonaws.com",
            "${trimprefix(aws_eks_cluster.kadikoy.identity[0].oidc[0].issuer, "https://")}:sub" : "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })
  depends_on = [
    aws_eks_cluster.kadikoy
  ]
}

resource "aws_iam_policy" "KarpenterControllerPolicy" {
  name = "kadikoy-KarpenterControllerPolicy"

  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "Karpenter"
      },
      {
        "Action" : "ec2:TerminateInstances",
        "Condition" : {
          "StringLike" : {
            "ec2:ResourceTag/karpenter.sh/provisioner-name" : "*"
          }
        },
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "ConditionalEC2Termination"
      },
      {
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : aws_iam_role.eks-node-group.arn,
        "Sid" : "PassNodeIAMRole"
      },
      {
        "Effect" : "Allow",
        "Action" : "eks:DescribeCluster",
        "Resource" : aws_eks_cluster.kadikoy.arn,
        "Sid" : "EKSClusterEndpointLookup"
      }
    ],
    "Version" : "2012-10-17"
  })
}


resource "aws_iam_role_policy_attachment" "KarpenterControllerPolicy" {
  policy_arn = aws_iam_policy.KarpenterControllerPolicy.arn
  role       = aws_iam_role.KarpenterControllerRole.name
  depends_on = [aws_iam_role.KarpenterControllerRole]
}

resource "aws_ec2_tag" "eks-sg-karpenter-tag" {
  resource_id = aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = aws_eks_cluster.kadikoy.name
}

# resource "kubernetes_config_map_v1_data" "aws-auth" {
#   force = true

#   lifecycle {
#     prevent_destroy = true
#   }

#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapRoles = yamlencode([{
#       rolearn  = aws_iam_role.KarpenterNodeRole.arn,
#       username = "system:node:{{EC2PrivateDNSName}}"
#       groups = [
#         "system:bootstrappers",
#         "system:nodes"
#       ]
#     }])
#   }
# }


resource "helm_release" "kadikoy-karpenter" {
  name = "karpenter"

  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "v0.29.2"
  namespace        = "karpenter"
  create_namespace = true

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.KarpenterNodeInstanceProfile.name
  }

  set {
    name  = "settings.aws.clusterName"
    value = aws_eks_cluster.kadikoy.name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.KarpenterControllerRole.arn
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = aws_eks_cluster.kadikoy.endpoint
  }

  set {
    name  = "settings.aws.clusterName"
    value = aws_eks_cluster.kadikoy.name
  }

  set {
    name  = "settings.aws.isolatedVPC"
    value = "true"
  }


  // To able to download at private network groups (#bk5Iutho2)
  set {
    name  = "controller.image.repository"
    value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/ecr-cache/karpenter/controller"
  }

  # set {
  #   name  = "controller.resources.requests.cpu"
  #   value = "1"
  # }

  # set {
  #   name  = "controller.resources.requests.memory"
  #   value = "1Gi"
  # }

  # set {
  #   name  = "controller.resources.limits.cpu"
  #   value = "1"
  # }

  # set {
  #   name  = "controller.resources.limits.memory"
  #   value = "1Gi"
  # }

  depends_on = [ 
    aws_vpc_endpoint.kadikoy-ecr-dkr,
    aws_vpc_endpoint.kadikoy-ecr-api,
    aws_vpc_endpoint.kadikoy-ec2,
    aws_vpc_endpoint.kadikoy-sts,
    aws_vpc_endpoint.kadikoy-ssm
   ]

  values = [
    jsonencode({
      "affinity" = {
        "nodeAffinity" = {
          "requiredDuringSchedulingIgnoredDuringExecution" = {
            "nodeSelectorTerms" = [
              {
                "matchExpressions" = [
                  {
                    "key"      = "eks.amazonaws.com/nodegroup"
                    "operator" = "In"
                    "values" = [
                      aws_eks_node_group.kadikoy_eks_private.node_group_name
                    ]
                  },
                ]
              },
            ]
          }
        }
        "podAntiAffinity" = {
          "requiredDuringSchedulingIgnoredDuringExecution" = [
            {
              "topologyKey" = "kubernetes.io/hostname"
            },
          ]
        }
      }
    })
  ]
}

resource "kubernetes_manifest" "karpenter-arm64-provisioner" {
  manifest = yamldecode(<<-EOF
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: kadikoy
spec:
  consolidation:
    enabled: true
  limits:
    resources:
      cpu: 1k
  providerRef:
    name: default
  requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values:
    - spot
  - key: kubernetes.io/arch
    operator: In
    values:
    - arm64
  - key: kubernetes.io/os
    operator: In
    values:
    - linux
  - key: karpenter.k8s.aws/instance-category
    operator: In
    values:
    - t
  - key: karpenter.k8s.aws/instance-generation
    operator: Gt
    values:
    - "2"
    EOF
  )
}

resource "aws_security_group" "karpenter-egress" {
  vpc_id = aws_vpc.kadikoy.id

  ingress {
    description      = "from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_vpc.kadikoy.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.kadikoy.ipv6_cidr_block]
  }

  egress {
    description      = "to VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_vpc.kadikoy.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.kadikoy.ipv6_cidr_block]
  }

  egress {
    description      = "to any"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    Name = "karpenter-egress"
    NetType= "ds-egress"
    Kartpenter="ds-egress"
  }
}


resource "aws_vpc_security_group_ingress_rule" "karpenter-egress-to-eks" {
  depends_on = [
    aws_security_group.karpenter-egress,
    aws_eks_cluster.kadikoy
  ]
  lifecycle {
    replace_triggered_by = [
      aws_security_group.karpenter-egress,
      aws_eks_cluster.kadikoy
    ]
  }
  security_group_id            = aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  description                  = "allow karpenter-egress to eks"
  referenced_security_group_id = aws_security_group.karpenter-egress.id
  ip_protocol                  = -1
}

resource "kubernetes_manifest" "karpenter-node-public" {
  manifest = yamldecode(<<-EOF
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: default
spec:
  amiFamily: Bottlerocket
  subnetSelector:
    NetType: ds-public
  securityGroupSelector:
    Kartpenter: ds-egress
    EOF
  )
}

resource "kubernetes_manifest" "karpenter-node-private" {
  manifest = yamldecode(<<-EOF
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: private
spec:
  amiFamily: Bottlerocket
  subnetSelector:
    NetType: ds-private
  securityGroupSelector:
    Kartpenter: ds-private
    EOF
  )
}