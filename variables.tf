variable "eks_oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster OIDC provider"
}

variable "eks_cluster_oidc_issuer_url" {
  type        = string
  description = "EKS cluster OIDC URL"
}

variable "hosted_zones" {
  type        = list(string)
  description = "List of hosted zones IDs to permit updates via ExternalDNS. Not implemented."
  default     = ["*"]
}

variable "k8s_namespace" {
  type        = string
  description = "K8s Namespace onto where ExternalDNS controller will be deployed."
  default     = "kube-system"
}