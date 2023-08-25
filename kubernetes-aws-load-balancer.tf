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
  role       = aws_iam_role.eks_kadikoy_node_group.name
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

resource "helm_release" "kadikoy-aws-load-balancer-controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace = "kube-system"

  set {
    name ="clusterName"
    value = aws_eks_cluster.kadikoy.name
  }
  set {
    name ="serviceAccount.create"
    value = "false"
  }
  set {
    name ="serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name = "image.repository"
    value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/kadikoy-cache/eks/aws-load-balancer-controller"
  }
  depends_on = [ 
    kubernetes_service_account.kadikoy-aws-load-balancer-controller,
    aws_iam_role_policy.kadikoy-ECRPullThroughCache,
    aws_eks_node_group.kadikoy_eks_private
  ]
}
