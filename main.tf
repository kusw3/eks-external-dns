# Based on https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md

locals {
  clean_oidc_url = replace(var.eks_cluster_oidc_issuer_url, "https://", "")
}

resource "random_id" "iam" {
  byte_length = 4
}

###
# AWS RESOURCES
###

# Creation of new role to be used by ExternalDNS pod
resource "aws_iam_role" "external_dns" {
  name = "allow_ExternalDNS_updates_${random_id.iam.hex}"

  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Federated": "${var.eks_oidc_provider_arn}"
          },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              "${local.clean_oidc_url}:sub": "system:serviceaccount:${var.k8s_namespace}:external-dns"
            }
          }
        }
      ]
    }
  EOF
}

# Route53 Entry management
resource "aws_iam_policy" "external_dns" {
  name        = "AllowExternalDNSUpdates_${random_id.iam.hex}"
  path        = "/"
  description = "Policy to Allow External-DNS K8s controller to manage recordsets"

  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "route53:ChangeResourceRecordSets"
          ],
          "Resource": [
            "arn:aws:route53:::hostedzone/*"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "route53:ListHostedZones",
            "route53:ListResourceRecordSets"
          ],
          "Resource": [
            "*"
          ]
        }
      ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

###
# KUBERNETES RESOURCES
###
resource "kubernetes_deployment" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = var.k8s_namespace
  }

  spec {
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "external-dns"
      }
    }

    template {
      metadata {
        labels = {
          app = "external-dns"
        }
      }

      spec {
        service_account_name            = kubernetes_service_account.external_dns.metadata[0].name
        automount_service_account_token = true

        container {
          image = "registry.opensource.zalan.do/teapot/external-dns:latest"
          name  = "external-dns"

          args = [
            "--source=service",
            "--source=ingress",
            "--provider=aws",
            "--policy=upsert-only",
            "--aws-zone-type=public",
            "--registry=txt",
            "--txt-owner-id=eks-external-dns-${random_id.iam.hex}"
          ]
        }

        security_context {
          fs_group = 65534
        }
      }
    }
  }
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = var.k8s_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
    }
  }

  automount_service_account_token = true

}

resource "kubernetes_cluster_role" "external_dns" {
  metadata {
    name = "external-dns"
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "external-dns" {
  metadata {
    name = "external-dns-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "external-dns"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "external-dns"
    namespace = var.k8s_namespace
  }
}