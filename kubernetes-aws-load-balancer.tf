resource "aws_iam_policy" "kadikoy_aws_load_balancer_controller" {
  name = "kadikoy_aws_load_balancer_controller"

  policy = file("${path.module}/json/aws_load_balancer_controller_v2_5-4_iam_policy.json")
}
data "aws_caller_identity" "current" {}


resource "aws_iam_role" "kadikoy_aws_load_balancer_controller" {
  name = "kadikoy_aws_load_balancer_controller"
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
            "${trimprefix(aws_eks_cluster.kadikoy.identity[0].oidc[0].issuer, "https://")}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
  depends_on = [
    aws_eks_cluster.kadikoy
  ]
}

resource "aws_iam_role_policy_attachment" "kadikoy_aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.kadikoy_aws_load_balancer_controller.arn
  role       = aws_iam_role.kadikoy_aws_load_balancer_controller.name
  depends_on = [
    aws_iam_role.kadikoy_aws_load_balancer_controller,
    aws_iam_policy.kadikoy_aws_load_balancer_controller
  ]
}



resource "kubernetes_service_account" "kadikoy-aws-load-balancer-controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "controller",
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.kadikoy_aws_load_balancer_controller.arn
    }
  }
  depends_on = [aws_eks_cluster.kadikoy]
}

resource "aws_security_group" "kadikoy-alb-public-default" {
  description = "Allow HTTP and HTTPS and ICMP for ALB"
  vpc_id      = aws_vpc.kadikoy.id

  ingress {
    description      = "from public remote http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "from public remote https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    to_port     = -1
    from_port   = -1
    description = "to public remote icmp ipv4"
    protocol    = "1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    to_port          = -1
    from_port        = -1
    description      = "to public remote icmp ipv6"
    protocol         = "58"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "kadikoy-alb-public-default"
  }
}

resource "aws_vpc_security_group_ingress_rule" "kadikoy-alb-public-default-tcp-80" {
  security_group_id            = aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  description                  = "allow kadikoy-alb-public-default sg to pod traffic tcp 80"
  referenced_security_group_id = aws_security_group.kadikoy-alb-public-default.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}
resource "aws_vpc_security_group_ingress_rule" "kadikoy-alb-public-default-tcp-8080" {
  security_group_id            = aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  description                  = "allow kadikoy-alb-public-default sg to pod traffic tcp 8080"
  referenced_security_group_id = aws_security_group.kadikoy-alb-public-default.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}
resource "aws_vpc_security_group_ingress_rule" "kadikoy-alb-public-default-ipv4-icmp" {
  security_group_id            = aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  description                  = "allow kadikoy-alb-public-default sg to pod traffic ipv4 icmp"
  referenced_security_group_id = aws_security_group.kadikoy-alb-public-default.id
  ip_protocol                  = "1"
  from_port                    = -1
  to_port                      = -1
}
resource "aws_vpc_security_group_ingress_rule" "kadikoy-alb-public-default-ipv6-icmp" {
  security_group_id            = aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  description                  = "allow kadikoy-alb-public-default sg to pod traffic ipv6 icmp"
  referenced_security_group_id = aws_security_group.kadikoy-alb-public-default.id
  ip_protocol                  = "58"
  from_port                    = -1
  to_port                      = -1
}
resource "aws_vpc_security_group_egress_rule" "kadikoy-alb-public-default-ipv4-icmp" {
  security_group_id            = aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  description                  = "allow kadikoy-alb-public-default sg to pod traffic ipv4 icmp"
  referenced_security_group_id = aws_security_group.kadikoy-alb-public-default.id
  ip_protocol                  = "1"
  from_port                    = -1
  to_port                      = -1
}
resource "aws_vpc_security_group_egress_rule" "kadikoy-alb-public-default-ipv6-icmp" {
  security_group_id            = aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  description                  = "allow kadikoy-alb-public-default sg to pod traffic ipv6 icmp"
  referenced_security_group_id = aws_security_group.kadikoy-alb-public-default.id
  ip_protocol                  = "58"
  from_port                    = -1
  to_port                      = -1
}

resource "aws_vpc_security_group_egress_rule" "kadikoy-alb-public-default-to-eks" {
  security_group_id            = aws_security_group.kadikoy-alb-public-default.id
  description                  = "allow from kadikoy-alb-public-default to eks"
  referenced_security_group_id =  aws_eks_cluster.kadikoy.vpc_config[0].cluster_security_group_id
  ip_protocol                  = -1
  from_port                    = -1
  to_port                      = -1
}
resource "helm_release" "kadikoy-aws-load-balancer-controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.kadikoy.name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  // To able to download at private network groups (#bk5Iutho2)
  set {
    name  = "image.repository"
    value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/kadikoy-cache/eks/aws-load-balancer-controller"
  }

  set {
    name  = "vpcId"
    value = aws_vpc.kadikoy.id
  }

  set {
    name  = "defaultTargetType"
    value = "ip"
  }

  set {
    name  = "enableShield"
    value = "false"
  }


  depends_on = [
    kubernetes_service_account.kadikoy-aws-load-balancer-controller,
    aws_iam_role_policy.kadikoy-ECRPullThroughCache,
    aws_eks_node_group.kadikoy_eks_private
  ]
}
