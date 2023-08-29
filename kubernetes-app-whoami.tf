resource "kubernetes_deployment_v1" "whoami" {
  metadata {
    name = "whomi"
    labels = {
      app = "whoami"
    }
    namespace = kubernetes_namespace_v1.suadiye.metadata[0].name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "whoami"
      }
    }

    template {
      metadata {
        labels = {
          app = "whoami"
        }
      }

      spec {
        container {
          image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/whoami"
          name  = "whoami"

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "whoami" {
  metadata {
    name      = "whoami"
    namespace = kubernetes_namespace_v1.suadiye.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.whoami.metadata[0].labels.app
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }

  depends_on = [
    helm_release.kadikoy-aws-load-balancer-controller # To prevent
  ]
}

# To create NLB to expose service to outside of the cluster

# resource "kubernetes_service" "whoami" {
#   metadata {
#     name      = "natgw"
#     namespace = kubernetes_namespace_v1.suadiye.metadata[0].name
#     annotations = {
#       "service.beta.kubernetes.io/aws-load-balancer-type" = "internal"
#       "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
#       "service.beta.kubernetes.io/aws-load-balancer-ip-address-type" = "dualstack"
#     }
#   }
#   spec {
#     ip_families = ["IPv6"]
#     ip_family_policy = "SingleStack"
#     selector = {
#       app = kubernetes_deployment_v1.whoami.metadata[0].labels.app
#     }
#     port {
#       port     = 65535
#       target_port = 65535
#       protocol = "TCP"
#     }
#     type = "ClusterIP"
#   }
# }

# resource "kubernetes_ingress_v1" "suadiye" {
#   # wait_for_load_balancer = true
#   metadata {
#     name      = "suadiye"
#     namespace = kubernetes_namespace_v1.suadiye.metadata[0].name
#     annotations = {
#       "alb.ingress.kubernetes.io/load-balancer-name" = kubernetes_namespace_v1.suadiye.metadata[0].name
#       "alb.ingress.kubernetes.io/group.name"         = "kadikoy-public"
#       "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
#       "alb.ingress.kubernetes.io/listen-ports"       = jsonencode([{ "HTTP" : 80 }]) //jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
#       "alb.ingress.kubernetes.io/target-type"        = "ip"
#       "alb.ingress.kubernetes.io/success-codes"      = "200-499"
#       "alb.ingress.kubernetes.io/ip-address-type"    = "dualstack"
#       "alb.ingress.kubernetes.io/security-groups"    = aws_security_group.kadikoy-alb-public-default.id //aws_default_security_group.kadikoy_default_sg.id
#       "alb.ingress.kubernetes.io/subnets"            = join(", ", aws_subnet.kadikoy_ds_public.*.id)
#     }
#   }

#   spec {
#     ingress_class_name = "alb"
#     default_backend {
#       service {
#         name = "whoami"
#         port {
#           number = 80
#         }
#       }
#     }

#     rule {
#       http {
#         path {
#           path_type = "Prefix"
#           backend {
#             service {
#               name = "whoami"
#               port {
#                 number = 80
#               }
#             }
#           }

#           path = "/"
#         }

#       }
#     }

#     # tls {
#     #   secret_name = "tls-secret"
#     # }
#   }

#   depends_on = [
#     helm_release.kadikoy-aws-load-balancer-controller # To prevent
#   ]

# }
