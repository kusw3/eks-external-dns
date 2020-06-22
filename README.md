# eks-external-dns
Setups external-dns controller on a given EKS cluster. Controller uses cluster RBAC through service accounts accessing IAM role.

No need for kiam or kube2iam.

This setup is based on [Setting up ExternalDNS for Services on AWS](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md#iam-permissions).

## Providers

| Name | Version |
|------|---------|
| aws | n/a |
| kubernetes | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| eks\_cluster\_oidc\_issuer\_url | EKS cluster OIDC URL | `string` | n/a | yes |
| eks\_oidc\_provider\_arn | ARN of the EKS cluster OIDC provider | `string` | n/a | yes |
| hosted\_zones | List of hosted zones IDs to permit updates via ExternalDNS. Not implemented. | `list(string)` | <pre>[<br>  "*"<br>]</pre> | no |
| k8s\_namespace | K8s Namespace onto where ExternalDNS controller will be deployed. | `string` | `"kube-system"` | no |

## Outputs

No output.

