resource "kubernetes_namespace_v1" "suadiye" {
  metadata {
    name = "suadiye"
  }
}

resource "kubernetes_deployment_v1" "whoami" {
  metadata {
    name = "whomi"
    labels = {
      app = "whoami"
    }
    namespace = "suadiye"
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
    namespace = "suadiye"
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
}

resource "kubernetes_ingress_v1" "suadiye" {
  # wait_for_load_balancer = true
  metadata {
    name      = "suadiye"
    namespace = "suadiye"
    annotations = {
      "alb.ingress.kubernetes.io/load-balancer-name" = "apps"
      "alb.ingress.kubernetes.io/group.name"         = "kadikoy-public"
      "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports"       = jsonencode([{ "HTTP" : 80 }])//jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/success-codes"      = "200-499"
      "alb.ingress.kubernetes.io/ip-address-type"    = "dualstack"
      "alb.ingress.kubernetes.io/security-groups"    = aws_security_group.kadikoy-alb-public-default.id //aws_default_security_group.kadikoy_default_sg.id
      "alb.ingress.kubernetes.io/subnets"            = join(", ", aws_subnet.kadikoy_ds_public.*.id)

    }
  }

  spec {
    ingress_class_name = "alb"
    default_backend {
      service {
        name = "whoami"
        port {
          number = 80
        }
      }
    }

    rule {
      http {
        path {
          path_type = "Prefix"
          backend {
            service {
              name = "whoami"
              port {
                number = 80
              }
            }
          }

          path = "/"
        }


      }
    }

    # tls {
    #   secret_name = "tls-secret"
    # }
  }
}
